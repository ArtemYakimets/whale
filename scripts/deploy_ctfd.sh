#!/bin/bash

set -e

echo "[INFO] Adding label to workers"

docker node update --label-add NAME=linux-1 linux-1
docker node update --label-add NAME=linux-2 linux-2

. /vagrant/scripts/setup.sh

echo "[INFO] Deploying CTFd..."

docker stack deploy -c ~/CTFd/docker-compose.yml ctfd_cluster