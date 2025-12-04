#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

SWARM_STATE_FILE="${ARTIFACTS_DIR}/swarm-initialized"
WORKER_TOKEN_FILE="${ARTIFACTS_DIR}/worker.token"
MANAGER_TOKEN_FILE="${ARTIFACTS_DIR}/manager.token"
SECRETS_SUMMARY_FILE="${ARTIFACTS_DIR}/secrets.generated"
STACK_FILE="/vagrant/docker/stack.yml"
STACK_NAME="whale"
CTFD_IMAGE_TAG="local/ctfd-whale:latest"
FRPS_IMAGE_TAG="local/frps:latest"
FRPC_IMAGE_TAG="local/frpc:latest"
FRP_VERSION="0.58.1"
SECRET_NAMES=(
  "mysql_root_password"
  "mysql_ctfd_password"
  "ctfd_admin_password"
  "ctfd_secret_key"
  "frp_shared_token"
)
CERT_DIR="/vagrant/certs"
TLS_CERT="${CERT_DIR}/ctfd-local.pem"
TLS_KEY="${CERT_DIR}/ctfd-local-key.pem"
TLS_CA_COPY="${CERT_DIR}/rootCA.pem"
MKCERT_BIN="/usr/local/bin/mkcert"
MKCERT_VERSION="1.4.4"
IMAGE_EXPORT_DIR="${ARTIFACTS_DIR}/images"

create_overlay_network() {
  local name="$1"
  local opts="$2"
  if ! docker network ls --format '{{.Name}}' | grep -q "^${name}$"; then
    log "Creating overlay network ${name}"
    # shellcheck disable=SC2086
    docker network create --driver overlay ${opts} "${name}" >/dev/null
  else
    log "Overlay network ${name} already exists"
  fi
}

persist_token() {
  local value="$1"
  local file="$2"
  if [[ ! -f "$file" || "$(cat "$file")" != "$value" ]]; then
    printf "%s" "$value" > "$file"
  fi
}

label_nodes() {
  docker node ls --format '{{.Hostname}}' | while read -r node; do
    [[ -z "$node" ]] && continue
    docker node update --label-add "name=${node}" "$node" >/dev/null 2>&1 || true
  done
}

worker_names_csv() {
  local fallback="$1"
  local names=()
  while read -r hostname role; do
    [[ -z "$hostname" ]] && continue
    if [[ "$role" == "worker" ]]; then
      names+=("$hostname")
    fi
  done < <(docker node ls --format '{{.Hostname}} {{.Role}}')
  if [[ ${#names[@]} -eq 0 && -n "$fallback" ]]; then
    names+=("$fallback")
  fi
  local IFS=,
  printf "%s" "${names[*]}"
}

wait_for_workers() {
  local target="$1"
  if [[ -z "$target" || ! "$target" =~ ^[0-9]+$ ]] || (( target <= 0 )); then
    return 0
  fi
  local retries=120
  while (( retries > 0 )); do
    local count
    count="$(docker node ls --filter role=worker --format '{{.Hostname}}' | grep -c . || true)"
    if (( count >= target )); then
      log "Detected ${count}/${target} worker nodes in the swarm"
      return 0
    fi
    sleep 5
    retries=$((retries - 1))
  done
  log "Timed out waiting for ${target} worker nodes" "WARN"
  return 1
}

ensure_swarm() {
  local advertise_addr="$1"
  local state
  state="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo inactive)"
  if [[ "$state" != "active" ]]; then
    log "Initializing Docker Swarm on ${advertise_addr}"
    docker swarm init --advertise-addr "$advertise_addr"
    touch "$SWARM_STATE_FILE"
  else
    log "Swarm already active"
  fi
}

refresh_tokens() {
  local worker_token manager_token
  worker_token="$(docker swarm join-token -q worker)"
  manager_token="$(docker swarm join-token -q manager)"
  persist_token "$worker_token" "$WORKER_TOKEN_FILE"
  persist_token "$manager_token" "$MANAGER_TOKEN_FILE"
  chmod 0644 "$WORKER_TOKEN_FILE" "$MANAGER_TOKEN_FILE"
}

secret_exists() {
  local name="$1"
  docker secret inspect "$name" >/dev/null 2>&1
}

record_secret_value() {
  local name="$1"
  local value="$2"
  touch "$SECRETS_SUMMARY_FILE"
  chmod 0600 "$SECRETS_SUMMARY_FILE"
  if ! grep -q "^${name}=" "$SECRETS_SUMMARY_FILE" 2>/dev/null; then
    printf "%s=%s\n" "$name" "$value" >> "$SECRETS_SUMMARY_FILE"
  fi
}

ensure_secret() {
  local name="$1"
  local file="${ARTIFACTS_DIR}/${name}.secret"
  if [[ ! -f "$file" ]]; then
    random_secret > "$file"
    chmod 0600 "$file"
  fi
  if ! secret_exists "$name"; then
    docker secret create "$name" "$file" >/dev/null
  fi
  record_secret_value "$name" "$(cat "$file")"
}

ensure_all_secrets() {
  for secret in "${SECRET_NAMES[@]}"; do
    ensure_secret "$secret"
  done
}

image_exists() {
  docker image inspect "$1" >/dev/null 2>&1
}

build_image() {
  local tag="$1"
  local dockerfile="$2"
  local extra_args=("${@:3}")
  if image_exists "$tag"; then
    log "Image ${tag} already present, skipping build"
    return
  fi
  log "Building image ${tag}"
  docker build -t "$tag" -f "$dockerfile" "${extra_args[@]}" /vagrant
}

ensure_images_built() {
  build_image "$CTFD_IMAGE_TAG" "/vagrant/docker/images/ctfd-whale/Dockerfile"
  build_image "$FRPS_IMAGE_TAG" "/vagrant/docker/images/frps/Dockerfile" "--build-arg" "FRP_VERSION=${FRP_VERSION}"
  build_image "$FRPC_IMAGE_TAG" "/vagrant/docker/images/frpc/Dockerfile" "--build-arg" "FRP_VERSION=${FRP_VERSION}"
}

ensure_mkcert_installed() {
  if command -v mkcert >/dev/null 2>&1; then
    return
  fi
  apt_update_once
  apt-get install -y libnss3-tools
  curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/v${MKCERT_VERSION}/mkcert-v${MKCERT_VERSION}-linux-amd64" -o "$MKCERT_BIN"
  chmod +x "$MKCERT_BIN"
}

ensure_tls_assets() {
  mkdir -p "$CERT_DIR"
  if [[ ! -f "$TLS_CERT" || ! -f "$TLS_KEY" ]]; then
    ensure_mkcert_installed
    "$MKCERT_BIN" -cert-file "$TLS_CERT" -key-file "$TLS_KEY" ctfd.local "*.10.10.56.10.nip.io"
  fi
  local mkcert_ca="${HOME}/.local/share/mkcert/rootCA.pem"
  if [[ -f "$mkcert_ca" ]]; then
    cp "$mkcert_ca" "$TLS_CA_COPY"
  fi
}

export_images() {
  mkdir -p "$IMAGE_EXPORT_DIR"
  declare -a images=("$CTFD_IMAGE_TAG" "$FRPS_IMAGE_TAG" "$FRPC_IMAGE_TAG")
  for image in "${images[@]}"; do
    local safe_name="${image//\//_}"
    safe_name="${safe_name//:/_}.tar"
    local target="${IMAGE_EXPORT_DIR}/${safe_name}"
    if [[ -f "$target" ]]; then
      log "Image archive ${target} already exists, skipping save"
      continue
    fi
    log "Exporting image ${image} to ${target}"
    docker save "$image" -o "$target"
  done
}

deploy_stack() {
  if [[ ! -f "$STACK_FILE" ]]; then
    log "Stack file ${STACK_FILE} missing" "ERROR"
    return 1
  fi
  log "Deploying stack ${STACK_NAME}"
  docker stack deploy --with-registry-auth -c "$STACK_FILE" "$STACK_NAME"
  docker service ls >/vagrant/artifacts/services.log 2>&1 || true
}

set_ctfd_config() {
  local container="$1"
  local key="$2"
  local value="$3"
  if ! docker exec "$container" python manage.py set_config "$key" "$value" >/dev/null; then
    log "Failed to set ${key}" "WARN"
    return 1
  fi
}

configure_ctfd_defaults() {
  local manager_ip="$1"
  local manager_name="$2"
  local container=""
  local attempts=120
  while (( attempts > 0 )); do
    container="$(docker ps --filter "name=${STACK_NAME}_ctfd" --format '{{.ID}}' | head -n 1)"
    [[ -n "$container" ]] && break
    sleep 5
    attempts=$((attempts - 1))
  done
  if [[ -z "$container" ]]; then
    log "Unable to find a running ctfd container for configuration" "WARN"
    return
  fi

  local domain_suffix="${manager_ip}.nip.io"
  declare -A configs=(
    ["whale:auto_connect_network"]="${STACK_NAME}_frp_containers"
    ["whale:frp_api_url"]="http://frpc:7400"
    ["whale:frp_http_port"]="8001"
    ["whale:frp_http_domain_suffix"]="$domain_suffix"
    ["whale:frp_direct_ip_address"]="$manager_ip"
    ["whale:frp_direct_port_minimum"]="10000"
    ["whale:frp_direct_port_maximum"]="10100"
    ["whale:docker_swarm_nodes"]="$(worker_names_csv "$manager_name")"
    ["whale:docker_subnet"]="172.22.0.0/16"
  )

  for key in "${!configs[@]}"; do
    local value="${configs[$key]}"
    log "Setting ${key}=${value}"
    set_ctfd_config "$container" "$key" "$value"
  done
}

manager::setup() {
  local node_name="$1"
  local node_ip="$2"
  local manager_ip="${3:-$node_ip}"
  local manager_name="${4:-$node_name}"
  local worker_target="${5:-0}"
  log "Running manager provisioning steps for ${node_name}"
  ensure_swarm "$manager_ip"
  refresh_tokens
  create_overlay_network "ctfd_default" "--attachable"
  create_overlay_network "frp_connect" "--attachable --internal --subnet 172.21.0.0/16"
  create_overlay_network "frp_containers" "--attachable --internal --subnet 172.22.0.0/16"
  label_nodes
  ensure_all_secrets
  ensure_images_built
  export_images
  ensure_tls_assets
  deploy_stack
  configure_ctfd_defaults "$manager_ip" "$manager_name"
  log "Manager provisioning completed"
}
