#!/bin/bash

set -e

. /vagrant/scripts/setup.sh

echo "[INFO] Deploying CTFd..."

docker stack deploy -c ~/CTFd/docker-compose.yml ctfd_cluster