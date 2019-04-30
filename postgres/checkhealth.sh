#!/bin/bash
set -eo pipefail

HOST="$(hostname -i || echo '127.0.0.1')"
USER="${POSTGRES_USER:-postgres}"
DB="${POSTGRES_DB:-postgres}"

export PGPASSWORD="${POSTGRES_PASSWORD:-}"

# A Postgres node is considered healthy if
# * it connects with the given username and password 
# * it returns 1 for a 'SELECT 1' SQL query

args=(
    # Force postgres to not use the local socket and test external connectivity
    --host "$HOST"
    --username "$USER"
    --dbname "$DB"
    --quiet --no-align --tuples-only
)

if select="$(echo 'SELECT 1' | psql "${args[@]}")" && [ "$select" = '1' ]; then
    exit 0
fi

exit 1