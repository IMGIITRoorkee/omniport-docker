# Network storage

Everything the portal serves under `/external/` comes from one s3fs mount of the S3 bucket `img-icc-bucket` (ap-south-1) at `codebase/omniport-backend/network_storage`.
Noticeboard attachments, File Manager, R Drive and RCloud all reach it through `django_filemanager`, so when the mount stops answering they all fail together.
The mount exists on production only.

| File | Installed as | Purpose |
| --- | --- | --- |
| `omniport-network-storage.sh` | `/usr/local/sbin/omniport-network-storage` | `release`, `await` and `watchdog` subcommands used by the units |
| `omniport-network-storage.service` | `/etc/systemd/system/` | Owns the s3fs process and the mount |
| `omniport-network-storage-watchdog.service` | `/etc/systemd/system/` | One probe-and-repair pass |
| `omniport-network-storage-watchdog.timer` | `/etc/systemd/system/` | Runs the watchdog every minute |

The units run as root, so they run a root-owned copy of the script rather than the checkout, which the `apps` account can write.

## How it fails

The s3fs daemon rarely dies.
It stops answering: a request to S3 stalls, everything behind it queues, and nginx sees reads that hang or fail with errno 107 (`Socket not connected`).
Recursive walks of the mount cause this, because every directory becomes an S3 listing and every file an S3 request, and the bucket holds large backup trees.

The watchdog probes with a real listing, bounded in time, on the host and inside each of `reverse-proxy`, `intranet-server` and `internet-server`.
On failure it writes a forensics snapshot to `/var/log/omniport-network-storage/`, remounts if the host side is dead, then restarts the three containers.
The containers bind the mount with `rprivate` propagation, so a host remount never reaches a running container and the restart is always needed.
It will not restart the containers unless the host mount is live, because a container started over the bare mountpoint writes uploads to the host disk.
After a repair it only alerts for 15 minutes, so a persistent fault cannot restart the site every minute.

Alerts and repairs go to syslog under the tag `omniport-network-storage`:

```bash
grep omniport-network-storage /var/log/syslog | tail -20
```

## Host settings the mount depends on

`/etc/cron.daily/mlocate` walks every filesystem that `/etc/updatedb.conf` does not exclude, and Ubuntu 18.04 does not exclude s3fs.
Both of these must be present:

```
PRUNEFS="fuse.s3fs ..."
PRUNEPATHS="/home/apps/omniport-docker/codebase/omniport-backend/network_storage ..."
```

Never run `du`, `find` or `grep -r` over `/home/apps` or `codebase/` without excluding `network_storage`.

## Installing

This takes the site down for about a minute, so do it in a maintenance window.
Pull the branch as `apps`, then as root:

```bash
cd /home/apps/omniport-docker
install -o root -g root -m 755 network-storage/omniport-network-storage.sh /usr/local/sbin/omniport-network-storage
install -o root -g root -m 644 network-storage/*.service network-storage/*.timer /etc/systemd/system/
systemctl daemon-reload

docker-compose stop reverse-proxy intranet-server internet-server
systemctl enable --now omniport-network-storage
grep -c ' fuse.s3fs ' /proc/self/mountinfo                # expect 1
ps -o pid,ppid,lstart,args -p "$(pgrep -d, -x s3fs)"      # expect one s3fs, started just now
docker-compose start reverse-proxy intranet-server internet-server
systemctl enable --now omniport-network-storage-watchdog.timer
```

The unit's `release` step aborts and unmounts any mount left by an s3fs started by hand, and that daemon then exits.
If `ps` still shows a second s3fs, stop it by its PID.
Re-run the two `install` lines and `systemctl daemon-reload` whenever a pull changes these files.

## Proving it works

A watchdog that has only been seen passing is not yet known to work.
Run both checks in the maintenance window, and read the syslog lines after each.

```bash
# The daemon dies: systemd remounts within seconds, the watchdog restarts the containers within two minutes.
systemctl kill -s KILL omniport-network-storage

# The daemon hangs, which is the real failure: the watchdog remounts and restarts the containers.
rm -f /var/lib/omniport-network-storage/last-repair
kill -STOP "$(systemctl show -p MainPID --value omniport-network-storage)"
```

Removing `last-repair` lifts the 15-minute cooldown left by the first check.
Each check passes when syslog shows the repair, a forensics file appears, and this prints `CONTAINER-READ-OK`:

```bash
docker-compose exec -T reverse-proxy ls /network_storage/public >/dev/null && echo CONTAINER-READ-OK
```

No syslog lines at all means the timer is not firing: check `systemctl list-timers omniport-network-storage-watchdog.timer`.

## Recovering by hand

Only needed when syslog says the watchdog gave up.
Read the newest forensics file first, then:

```bash
systemctl restart omniport-network-storage
cd /home/apps/omniport-docker && docker-compose restart reverse-proxy intranet-server internet-server
```

## Traps

- `findmnt`, `systemctl status` and `mountpoint -q` all report a healthy mount while every read fails. Only a read bounded by a timeout proves it, and a read sent to a hung mount ignores `kill -9`.
- Listing the mountpoint proves nothing on its own: the repository tracks `public/` and `protected/` placeholders there, so the bare directory looks right. Check `/proc/self/mountinfo` too.
- An unset `$NS` turns `findmnt -T "$NS"` into a check of `/` and `ls "$NS/public"` into `ls /public`. Print it before trusting any check that uses it.
- `nonempty` lets a second s3fs mount silently on top of the first. Stacked mounts hide a dead daemon underneath; `release` clears the whole stack.
- The `reverse-proxy` container logs in UTC and the host in IST, so timelines across the two are 5h30m apart. Its busybox has `zcat` but no `zgrep`.

## Upgrading s3fs

Production runs s3fs 1.82 from 2018, built on GnuTLS and libgcrypt, which logs nothing.
To build a current release against OpenSSL, the TLS library curl uses must change too:

```bash
apt-get install -y automake autotools-dev g++ git libcurl4-openssl-dev libfuse-dev libssl-dev libxml2-dev make pkg-config
git clone https://github.com/s3fs-fuse/s3fs-fuse.git /usr/local/src/s3fs-fuse
cd /usr/local/src/s3fs-fuse && git checkout <newest release tag>
./autogen.sh && ./configure --prefix=/usr --with-openssl && make -j4
ldd src/s3fs | grep -E 'gnutls|gcrypt'                    # expect no output
```

Before installing it, mount it once over a scratch directory that holds only a `.gitignore`, and set the unit's options from what happens: newer releases may treat `nonempty` differently.
