#!/bin/sh
set -e

if [ -f /run/secrets/frp_token ]; then
    TOKEN=$(cat /run/secrets/frp_token)
    export FRP_TOKEN="$TOKEN"
    
    sed -i "s|token = /run/secrets/frp_token|token = $TOKEN|g" /conf/frps.ini
fi

exec /usr/local/bin/frps -c /conf/frps.ini

