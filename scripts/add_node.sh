#!/bin/bash

set -e

echo "[INFO] Adding labels to worker nodes..."

sleep 10

docker node update --label-add name=linux-3 linux-3 2>/dev/null || echo "[WARN] linux-3 not available yet"

echo "[INFO] Worker node added!"