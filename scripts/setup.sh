#!/bin/bash

set -e

generate_token() {
    local LENGTH=${1:-32}  
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$LENGTH"
    echo
}

echo "[INFO] Setting up manager"

# Set working directory
DEPLOY_DIR="$HOME/ctfd-deployment"

echo "[INFO] Creating deployment directory..."
mkdir -p "$DEPLOY_DIR"

echo "[INFO] Copying configuration files from /vagrant..."
cp -r /vagrant/conf "$DEPLOY_DIR/"
cp /vagrant/docker-compose.yml "$DEPLOY_DIR/"
cp /vagrant/Dockerfile.ctfd-whale "$DEPLOY_DIR/"
cp /vagrant/Dockerfile.frps "$DEPLOY_DIR/"
cp /vagrant/Dockerfile.frpc "$DEPLOY_DIR/"
cp -r /vagrant/docker "$DEPLOY_DIR/"

echo "[INFO] Generating FRP token..."
FRP_TOKEN=$(generate_token 64)
echo "$FRP_TOKEN" | docker secret create frp_token - || true

echo "[INFO] Creating data directories..."
mkdir -p "$DEPLOY_DIR/.data/CTFd/logs"
mkdir -p "$DEPLOY_DIR/.data/CTFd/uploads"
mkdir -p "$DEPLOY_DIR/.data/mysql"
mkdir -p "$DEPLOY_DIR/.data/redis"

echo "[INFO] Building Docker images..."
cd "$DEPLOY_DIR"

echo "[INFO] Building CTFd-Whale image..."
docker build -f Dockerfile.ctfd-whale -t ctfd-whale:latest .

echo "[INFO] Building FRP Server image..."
docker build -f Dockerfile.frps -t frps:latest .

echo "[INFO] Building FRP Client image..."
docker build -f Dockerfile.frpc -t frpc:latest .

echo "[INFO] Deploying Docker stack..."
docker stack deploy -c docker-compose.yml ctfd

echo "[INFO] Waiting for CTFd to be ready..."
sleep 30

echo "[INFO] Configuring Whale plugin..."
docker exec $(docker ps -q -f name=ctfd_ctfd) python manage.py set_config whale:auto_connect_network ctfd_frp_containers || true

echo "[INFO] CTFd setup complete"
echo "[INFO] Deployment directory: $DEPLOY_DIR"