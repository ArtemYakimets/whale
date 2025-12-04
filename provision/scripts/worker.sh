#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

WORKER_TOKEN_FILE="${ARTIFACTS_DIR}/worker.token"
IMAGE_EXPORT_DIR="/vagrant/artifacts/images"
LOCAL_IMAGES=(
  "local/ctfd-whale:latest"
  "local/frps:latest"
  "local/frpc:latest"
)

remote_ssh() {
  local manager_ip="$1"
  shift
  local key_path="/vagrant/provision/keys/vagrant_insecure"
  if [[ ! -f "$key_path" ]]; then
    log "Insecure key not found at $key_path" "WARN"
    return 0
  fi
  ssh -i "$key_path" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    vagrant@"${manager_ip}" "$@" >/dev/null 2>&1 || true
}

join_swarm_if_needed() {
  local manager_addr="$1"
  local token="$2"
  local state
  state="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo inactive)"
  if [[ "$state" != "active" ]]; then
    local attempts=12
    local delay=10
    local joined=false
    for ((i=1; i<=attempts; i++)); do
      log "Joining swarm manager ${manager_addr} (attempt ${i}/${attempts})"
      if docker swarm join --token "$token" "${manager_addr}:2377"; then
        joined=true
        break
      fi
      sleep "$delay"
    done
    if [[ "$joined" == false ]]; then
      log "Failed to join swarm manager ${manager_addr} after ${attempts} attempts" "ERROR"
    fi
  else
    log "Node already part of a swarm"
  fi
}

load_local_images() {
  for image in "${LOCAL_IMAGES[@]}"; do
    local archive="${IMAGE_EXPORT_DIR}/${image//\//_}.tar"
    if [[ -f "$archive" ]]; then
      log "Loading image ${image} from ${archive}"
      docker load -i "$archive" >/dev/null
    fi
  done
}

worker::setup() {
  local node_name="$1"
  local node_ip="$2"
  local manager_ip="$3"
  local manager_name="$4"

  log "Provisioning worker ${node_name}"
  wait_for_file "$WORKER_TOKEN_FILE" 600
  local token
  token="$(cat "$WORKER_TOKEN_FILE")"
  join_swarm_if_needed "$manager_ip" "$token"
  load_local_images
  remote_ssh "$manager_ip" docker node update --label-add "name=${node_name}" "${node_name}"
  log "Worker provisioning finished for ${node_name}"
}
