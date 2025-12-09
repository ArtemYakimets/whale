#!/bin/bash

set -e

IP=$1
NAME=$2

if [ "$NAME" == "manager" ]; then
  echo "[INFO] Initializing Docker Swarm manager..."
  docker swarm init --advertise-addr "$IP" || true

  echo "[INFO] Add label to node $NAME"
  docker node update --label-add $NAME $NAME

  TOKEN=$(docker swarm join-token -q worker)
  echo "$TOKEN" > /vagrant/secrets/worker_token
  echo "[INFO] Swarm manager initialized. Worker token saved to /vagrant/secrets/worker_token"
else
  echo "[INFO] Joining node $NAME as worker..."
  while [ ! -f /vagrant/secrets/worker_token ]; do
    echo "[WAIT] Waiting for manager to generate join token..."
    sleep 2
  done

  TOKEN=$(cat /vagrant/secrets/worker_token)
  docker swarm join --token "$TOKEN" 192.168.56.10:2377 || true

  echo "[INFO] Node $NAME successfully joined the Swarm cluster."
  
  echo "[INFO] Adding label to worker node $NAME"
  docker node update --label-add NAME=$NAME $NAME
fi