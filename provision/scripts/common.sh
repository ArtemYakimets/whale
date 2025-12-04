#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

common::setup() {
  local node_name="$1"
  local node_ip="$2"
  log "Starting common provisioning for ${node_name} (${node_ip})"
  install_common_packages
  install_docker
  ensure_kernel_settings
  ensure_artifacts_dir
  if [[ -f /vagrant/provision/keys/vagrant_insecure ]]; then
    chmod 0600 /vagrant/provision/keys/vagrant_insecure || true
  fi
  log "Common provisioning finished for ${node_name}"
}
