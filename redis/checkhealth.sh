#!/bin/bash
set -eo pipefail

host="$(hostname -i || echo '127.0.0.1')"

# A Redis node is considered healthy if
# * it responds 'PONG' to every ping 

if ping="$(redis-cli -h "$host" ping)" && [ "$ping" = 'PONG' ]; then
    exit 0
fi

exit 1