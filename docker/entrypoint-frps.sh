#!/bin/sh
set -e

# Read token from Docker secret
if [ -f /run/secrets/frp_token ]; then
    TOKEN=$(cat /run/secrets/frp_token)
    export FRP_TOKEN="$TOKEN"
    
    # Replace token placeholder in config
    sed -i "s|token = /run/secrets/frp_token|token = $TOKEN|g" /conf/frps.ini
fi

# Execute frps
exec /usr/local/bin/frps -c /conf/frps.ini

