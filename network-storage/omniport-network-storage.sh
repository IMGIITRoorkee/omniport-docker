#!/bin/bash
# Keeps the s3fs mount behind /external/ serving: release unmounts every stacked
# s3fs mount, await waits for a live one, watchdog probes and repairs.
set -u

NS=${NS:-/home/apps/omniport-docker/codebase/omniport-backend/network_storage}
COMPOSE_DIR=${COMPOSE_DIR:-/home/apps/omniport-docker}
MOUNTINFO=${MOUNTINFO:-/proc/self/mountinfo}
FUSE_CONNECTIONS=${FUSE_CONNECTIONS:-/sys/fs/fuse/connections}
STATE_DIR=${STATE_DIR:-/var/lib/omniport-network-storage}
LOG_DIR=${LOG_DIR:-/var/log/omniport-network-storage}
PROBE_TIMEOUT=${PROBE_TIMEOUT:-10}   # seconds a listing may take before the mount counts as hung
PROBE_INTERVAL=${PROBE_INTERVAL:-5}  # seconds between probes
PROBE_ATTEMPTS=3                     # consecutive failed probes before a repair
AWAIT_ATTEMPTS=12                    # probes to wait for a fresh mount to answer
RELEASE_ATTEMPTS=8                   # unmounts to try before giving up on a stack
COOLDOWN=900                         # seconds after a repair during which failures only alert
UNIT=omniport-network-storage.service
SERVICES="reverse-proxy intranet-server internet-server"

log() { logger -t omniport-network-storage "$*"; }
alert() { logger -p user.err -t omniport-network-storage "$*"; }

# Connection ids of the s3fs mounts at $NS, bottom of the stack first.
s3fs_connections() {
    awk -v ns="$NS" '$5 == ns {
        for (i = 7; i <= NF && $i != "-"; i++);
        if ($(i + 1) == "fuse.s3fs") { split($3, dev, ":"); print dev[2] }
    }' "$MOUNTINFO"
}

# A request already sent to a hung FUSE daemon ignores even SIGKILL, so the
# probe runs in the background and is abandoned rather than waited on.
bounded() {
    "$@" >/dev/null 2>&1 &
    local pid=$! tenths=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$tenths" -ge $((PROBE_TIMEOUT * 10)) ]; then
            kill "$pid" 2>/dev/null
            return 1
        fi
        sleep 0.1
        tenths=$((tenths + 1))
    done
    wait "$pid"
}

# The repository commits placeholder directories into the mountpoint, so a
# listing alone cannot tell a live mount from the bare directory underneath.
host_alive() { [ -n "$(s3fs_connections)" ] && bounded ls -a "$NS"; }

compose() { (cd "$COMPOSE_DIR" && docker-compose "$@"); }

container_alive() {
    local svc
    for svc in $SERVICES; do
        bounded compose exec -T "$svc" sh -c 'grep -q " /network_storage fuse.s3fs " /proc/mounts && ls -a /network_storage' \
            || return 1
    done
}

release() {
    local i conn conns
    for ((i = 0; i < RELEASE_ATTEMPTS; i++)); do
        conns=$(s3fs_connections)
        [ -z "$conns" ] && return 0
        for conn in $conns; do
            { echo 1 > "$FUSE_CONNECTIONS/$conn/abort"; } 2>/dev/null
        done
        umount -l "$NS"
    done
    alert "could not release the s3fs mounts stacked at $NS"
    return 1
}

await_mount() {
    local i
    for ((i = 0; i < AWAIT_ATTEMPTS; i++)); do
        host_alive && return 0
        sleep "$PROBE_INTERVAL"
    done
    return 1
}

snapshot() {
    local out
    mkdir -p "$LOG_DIR"
    out="$LOG_DIR/forensics-$(date +%Y%m%d-%H%M%S).log"
    {
        echo "== s3fs processes"; ps -o pid,lstart,rss,nlwp,stat,args -p "$(pgrep -d, -x s3fs)"
        echo "== processes blocked on FUSE"; ps -eo pid,wchan:32,lstart,args | awk '$2 ~ /request_wait|fuse/'
        echo "== s3fs mounts"; grep ' fuse.s3fs ' "$MOUNTINFO"
        echo "== FUSE requests waiting"; grep -H . "$FUSE_CONNECTIONS"/*/waiting
        echo "== unit"; systemctl status "$UNIT" --no-pager -l; journalctl -u "$UNIT" -n 200 --no-pager
        echo "== kernel"; dmesg -T | tail -50
    } > "$out" 2>&1
    log "forensics written to $out"
}

watchdog() {
    local i last now
    for ((i = 0; i < PROBE_ATTEMPTS; i++)); do
        host_alive && container_alive && return 0
        sleep "$PROBE_INTERVAL"
    done
    snapshot

    mkdir -p "$STATE_DIR"
    last=$(cat "$STATE_DIR/last-repair" 2>/dev/null || echo 0)
    now=$(date +%s)
    if [ $((now - last)) -lt "$COOLDOWN" ]; then
        alert "network storage still failing within ${COOLDOWN}s of the last repair; not repairing again"
        return 1
    fi
    echo "$now" > "$STATE_DIR/last-repair"

    if ! host_alive; then
        alert "host mount at $NS is not answering; restarting $UNIT"
        systemctl restart "$UNIT"
        if ! await_mount; then
            alert "remount of $NS failed; leaving the containers on the old mount so nothing writes to the bare directory"
            return 1
        fi
    fi

    alert "restarting $SERVICES onto the live mount"
    # shellcheck disable=SC2086 # SERVICES is a list of names
    compose restart $SERVICES
    if ! container_alive; then
        alert "containers still cannot read network storage after a restart"
        return 1
    fi
    log "network storage repaired"
}

case "${1:-}" in
    release) release ;;
    await) await_mount ;;
    watchdog) watchdog ;;
    *) echo "usage: $0 release|await|watchdog" >&2; exit 2 ;;
esac
