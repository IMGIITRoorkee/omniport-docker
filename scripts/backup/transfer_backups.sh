#!/bin/bash

# Ship the nightly backups to AWS over SCP, then delete each local copy once
# its transfer has been verified. Run from cron after the backup job finishes.
# Configuration comes from backup_transfer.env (see the .example file).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/backup_transfer.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: ${ENV_FILE} not found. Copy backup_transfer.env.example and fill it in." >&2
    exit 1
fi
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

AWS_PORT="${AWS_PORT:-22}"
BACKUP_GLOB="${BACKUP_GLOB:-*}"
DELETE_AFTER_TRANSFER="${DELETE_AFTER_TRANSFER:-true}"
LOG_FILE="${LOG_FILE:-}"

for var in BACKUP_DIR AWS_HOST AWS_USER SSH_KEY_PATH REMOTE_DIR; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: required variable ${var} is not set in ${ENV_FILE}" >&2
        exit 1
    fi
done

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -n "$LOG_FILE" ]; then
        echo "$line" | tee -a "$LOG_FILE"
    else
        echo "$line"
    fi
}

if [ ! -d "$BACKUP_DIR" ]; then
    log "ERROR: backup directory ${BACKUP_DIR} does not exist"
    exit 1
fi
if [ ! -f "$SSH_KEY_PATH" ]; then
    log "ERROR: SSH key ${SSH_KEY_PATH} not found"
    exit 1
fi

# BatchMode makes ssh/scp fail instead of hanging on a prompt when key auth fails
SCP_OPTS=(-i "$SSH_KEY_PATH" -P "$AWS_PORT" -o BatchMode=yes)
SSH_OPTS=(-i "$SSH_KEY_PATH" -p "$AWS_PORT" -o BatchMode=yes)

shopt -s nullglob
files=("$BACKUP_DIR"/$BACKUP_GLOB)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
    log "No backup files matching '${BACKUP_GLOB}' in ${BACKUP_DIR}; nothing to do."
    exit 0
fi

log "Found ${#files[@]} backup file(s) to transfer to ${AWS_USER}@${AWS_HOST}:${REMOTE_DIR}"

failures=0

# Handle one file at a time so a single bad transfer never costs us the rest
# and never delete a local file until its remote copy is confirmed.
for file in "${files[@]}"; do
    [ -f "$file" ] || continue
    name="$(basename "$file")"

    log "Transferring ${name}..."
    if ! scp "${SCP_OPTS[@]}" "$file" "${AWS_USER}@${AWS_HOST}:${REMOTE_DIR}/"; then
        log "ERROR: scp failed for ${name}; keeping local copy"
        failures=$((failures + 1))
        continue
    fi

    # A matching byte count is our proof the upload completed intact
    local_size="$(stat -c '%s' "$file")"
    remote_size="$(ssh "${SSH_OPTS[@]}" "${AWS_USER}@${AWS_HOST}" \
        "stat -c '%s' '${REMOTE_DIR}/${name}'" 2>/dev/null || echo "")"

    if [ "$local_size" != "$remote_size" ]; then
        log "ERROR: size mismatch for ${name} (local=${local_size}, remote=${remote_size:-missing}); keeping local copy"
        failures=$((failures + 1))
        continue
    fi

    log "Verified ${name} (${local_size} bytes) on remote"

    if [ "$DELETE_AFTER_TRANSFER" = "true" ]; then
        rm -f "$file"
        log "Deleted local ${name}"
    fi
done

if [ "$failures" -ne 0 ]; then
    log "Completed with ${failures} failure(s); local copies of failed files were retained."
    exit 1
fi

log "All backups transferred and verified successfully."
