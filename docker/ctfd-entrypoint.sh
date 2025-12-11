#!/bin/bash
set -e

if [ -f /run/secrets/ctfd_secret_key ]; then
    export SECRET_KEY=$(cat /run/secrets/ctfd_secret_key)
fi

# Execute the original entrypoint
exec /opt/CTFd/docker-entrypoint.sh "$@"

