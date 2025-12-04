#!/usr/bin/env bash
set -euo pipefail

CONFIG_TEMPLATE="${FRP_CONFIG_TEMPLATE:-/etc/frp/frps.ini}"
TOKEN_FILE="${FRP_TOKEN_FILE:-/run/secrets/frp_shared_token}"
TOKEN_VALUE="${FRP_SHARED_TOKEN:-}"

if [[ -z "$TOKEN_VALUE" && -f "$TOKEN_FILE" ]]; then
  TOKEN_VALUE="$(<"$TOKEN_FILE")"
fi

if [[ -z "$TOKEN_VALUE" ]]; then
  echo "FRP token is required" >&2
  exit 1
fi

export FRP_SHARED_TOKEN="$TOKEN_VALUE"
mkdir -p /run/frp
envsubst < "$CONFIG_TEMPLATE" > /run/frp/frps.ini
exec /usr/local/bin/frps -c /run/frp/frps.ini
