#!/bin/bash
set -e

# Read SECRET_KEY from Docker secret and pass it via env to the child process
if [ -f /run/secrets/ctfd_secret_key ]; then
    exec env SECRET_KEY="$(cat /run/secrets/ctfd_secret_key)" /opt/CTFd/docker-entrypoint.sh "$@"
else
    exec /opt/CTFd/docker-entrypoint.sh "$@"
fi
