#!/bin/bash

set -e

echo "[INFO] Adding labels to worker nodes..."

sleep 10

docker node update --label-add name=linux-1 linux-1 2>/dev/null || echo "[WARN] linux-1 not available yet"
docker node update --label-add name=linux-2 linux-2 2>/dev/null || echo "[WARN] linux-2 not available yet"

echo "[INFO] Running main setup..."
. /vagrant/scripts/setup.sh

echo "[INFO] CTFd deployment complete!"