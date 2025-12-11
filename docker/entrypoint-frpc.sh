#!/bin/sh
set -e

if [ -f /run/secrets/frp_token ]; then
    TOKEN=$(cat /run/secrets/frp_token)
    export FRP_TOKEN="$TOKEN"
    
    sed -i "s|token = /run/secrets/frp_token|token = $TOKEN|g" /conf/frpc.ini
fi

exec /usr/local/bin/frpc -c /conf/frpc.ini

