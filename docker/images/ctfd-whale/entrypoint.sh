#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_ENTRYPOINT="/opt/CTFd/docker-entrypoint.sh"

load_secret_var() {
  local var_name="$1"
  local file_var="${var_name}_FILE"
  local file_path="${!file_var:-}"
  if [[ -n "$file_path" && -f "$file_path" ]]; then
    export "$var_name"="$(<"$file_path")"
  fi
}

load_secret_var "CTFD_ADMIN_PASSWORD"
load_secret_var "CTFD_SECRET_KEY"
load_secret_var "CTFD_DB_PASSWORD"

if [[ -n "${CTFD_DB_PASSWORD:-}" ]]; then
  export DATABASE_URL="mysql+pymysql://${CTFD_DB_USER:-ctfd}:${CTFD_DB_PASSWORD}@${CTFD_DB_HOST:-mysql}/${CTFD_DB_NAME:-ctfd}"
fi

exec "$ORIGINAL_ENTRYPOINT" "$@"
