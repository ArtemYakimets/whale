#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-}"
NODE_NAME="${2:-}"
NODE_IP="${3:-}"
MANAGER_IP="${4:-}"
MANAGER_NAME="${5:-swarm-mgr}"
WORKER_COUNT="${6:-0}"

if [[ -z "${ROLE}" || -z "${NODE_NAME}" || -z "${NODE_IP}" ]]; then
  echo "Usage: bootstrap.sh <role> <node-name> <node-ip> [manager-ip]" >&2
  exit 1
fi

if [[ -z "${MANAGER_IP}" ]]; then
  MANAGER_IP="${NODE_IP}"
fi

SCRIPT_ROOT="/vagrant/provision/scripts"

if [[ ! -d "${SCRIPT_ROOT}" ]]; then
  echo "Script root ${SCRIPT_ROOT} not found" >&2
  exit 1
fi

source "${SCRIPT_ROOT}/common.sh"
common::setup "${NODE_NAME}" "${NODE_IP}"

case "${ROLE}" in
  manager)
    source "${SCRIPT_ROOT}/manager.sh"
    manager::setup "${NODE_NAME}" "${NODE_IP}" "${MANAGER_IP}" "${MANAGER_NAME}" "${WORKER_COUNT}"
    ;;
  worker)
    source "${SCRIPT_ROOT}/worker.sh"
    worker::setup "${NODE_NAME}" "${NODE_IP}" "${MANAGER_IP}" "${MANAGER_NAME}"
    ;;
  *)
    echo "Unknown role: ${ROLE}" >&2
    exit 1
    ;;
 esac
