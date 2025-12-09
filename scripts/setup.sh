#!/bin/bash

set -e

generate_token() {
    local LENGTH=${1:-32}  
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$LENGTH"
    echo
}

echo "[INFO] Setting up manager"

echo "[INFO] Generating FRP token..."
FRP_TOKEN=$(generate_token 64)
echo "$FRP_TOKEN" | docker secret create frp_token - || true

echo "[INFO] Cloning CTFd repository..."
git clone https://github.com/CTFd/CTFd --depth=1

mv /vagrant/docker-compose.yml ~/CTFd/docker-compose.yml
mv /vagrant/conf/ ~/CTFd/conf/
