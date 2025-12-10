#!/bin/bash

set -e

IP=$1
NAME=$2

if [ "$NAME" == "manager" ]; then
  echo "[INFO] Initializing Docker Swarm manager..."
  docker swarm init --advertise-addr "$IP" || true
  
  echo "[INFO] Waiting for Swarm to be fully ready..."
  sleep 5

  echo "[INFO] Add label to node $NAME"
  docker node update --label-add $NAME $NAME

  TOKEN=$(docker swarm join-token -q worker)
  mkdir -p /vagrant/secrets
  echo "$TOKEN" > /vagrant/secrets/worker_token
  echo "[INFO] Swarm manager initialized. Worker token saved to /vagrant/secrets/worker_token"
else
  echo "[INFO] Joining node $NAME as worker..."
  while [ ! -f /vagrant/secrets/worker_token ]; do
    echo "[WAIT] Waiting for manager to generate join token..."
    sleep 2
  done

  TOKEN=$(cat /vagrant/secrets/worker_token)
  
  echo "[INFO] Waiting for manager Swarm port 2377 to be ready..."
  RETRIES=0
  MAX_RETRIES=30
  until timeout 2 bash -c "cat < /dev/null > /dev/tcp/192.168.56.10/2377" 2>/dev/null; do
    if [ $RETRIES -ge $MAX_RETRIES ]; then
      echo "[ERROR] Manager Swarm port not reachable after $MAX_RETRIES attempts"
      exit 1
    fi
    echo "[WAIT] Manager swarm port not ready yet, retrying... ($((RETRIES+1))/$MAX_RETRIES)"
    sleep 3
    RETRIES=$((RETRIES+1))
  done
  
  echo "[INFO] Manager port is ready, joining swarm..."
  docker swarm join --token "$TOKEN" 192.168.56.10:2377 || true

  echo "[INFO] Node $NAME successfully joined the Swarm cluster."
fi