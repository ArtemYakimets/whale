#!/usr/bin/env bash
# shellcheck disable=SC1090
set -euo pipefail

ARTIFACTS_DIR="/vagrant/artifacts"
APT_UPDATED_SENTINEL="/var/run/.vagrant-apt-update"
DOCKER_KEYRING="/etc/apt/keyrings/docker.gpg"
DOCKER_LIST_FILE="/etc/apt/sources.list.d/docker.list"

log() {
  local level="${2:-INFO}"
  local message="$1"
  echo "[$(date -u +%H:%M:%S)] [$level] $message"
}

apt_update_once() {
  if [[ ! -f "${APT_UPDATED_SENTINEL}" ]]; then
    if [[ -f "$DOCKER_LIST_FILE" && ! -f "$DOCKER_KEYRING" ]]; then
      log "Docker repo present but key missing; temporarily disabling repository" "WARN"
      rm -f "$DOCKER_LIST_FILE"
    fi
    log "Running apt-get update"
    apt-get update
    touch "${APT_UPDATED_SENTINEL}"
  fi
}

install_common_packages() {
  apt_update_once
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    jq \
    git \
    python3-pip \
    openssh-client \
    unzip \
    htop \
    openssl
}

ensure_docker_repository() {
  local keyring="$DOCKER_KEYRING"
  if [[ ! -f "$keyring" ]]; then
    log "Adding Docker repository key"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --batch --yes --dearmor -o "$keyring"
    chmod a+r "$keyring"
  fi

  local repo="deb [arch=amd64 signed-by=$keyring] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  local list_file="$DOCKER_LIST_FILE"
  if [[ ! -f "$list_file" ]] || ! grep -q "$keyring" "$list_file" 2>/dev/null; then
    log "Adding Docker apt repository"
    echo "$repo" > "$list_file"
    rm -f "${APT_UPDATED_SENTINEL}"
  fi
}

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    ensure_docker_repository
    apt_update_once
    log "Installing Docker Engine"
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  fi
  systemctl enable docker >/dev/null
  systemctl start docker
  if id vagrant >/dev/null 2>&1; then
    usermod -aG docker vagrant || true
  fi
}

ensure_kernel_settings() {
  cat <<'SYSCTL' > /etc/sysctl.d/99-whale.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
SYSCTL
  sysctl --system >/dev/null
}

ensure_artifacts_dir() {
  mkdir -p "${ARTIFACTS_DIR}"
  chmod 0777 "${ARTIFACTS_DIR}"
}

wait_for_file() {
  local file="$1"
  local timeout="${2:-300}"
  local elapsed=0
  until [[ -s "$file" ]]; do
    if (( elapsed >= timeout )); then
      log "Timeout waiting for $file" "ERROR"
      return 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

random_secret() {
  openssl rand -hex 24
}

file_contains() {
  local needle="$1"
  local file="$2"
  [[ -f "$file" ]] && grep -q "$needle" "$file"
}
