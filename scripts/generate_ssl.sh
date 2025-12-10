#!/bin/bash

set -e

CERT_DIR="${1:-$HOME/ctfd-deployment/certs}"

echo "[INFO] Installing mkcert..."
sudo apt-get update
sudo apt-get install -y libnss3-tools wget

# Download and install mkcert
if ! command -v mkcert &> /dev/null; then
    sudo wget -q "https://dl.filippo.io/mkcert/latest?for=linux/amd64" -O /usr/local/bin/mkcert
    sudo chmod +x /usr/local/bin/mkcert
fi

echo "[INFO] Creating certificate directory..."
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "[INFO] Installing local CA..."
CAROOT="$CERT_DIR/ca" mkcert -install

echo "[INFO] Generating web interface certificates (192.168.56.10)..."
CAROOT="$CERT_DIR/ca" mkcert \
    -cert-file "$CERT_DIR/web.crt" \
    -key-file "$CERT_DIR/web.key" \
    192.168.56.10 \
    "*.192.168.56.10.nip.io" \
    localhost \
    127.0.0.1

echo "[INFO] Generating Docker TLS certificates..."
# CA certificate (copy from mkcert CA)
cp "$CERT_DIR/ca/rootCA.pem" "$CERT_DIR/docker-ca.crt"

# Generate Docker client certificate
CAROOT="$CERT_DIR/ca" mkcert \
    -cert-file "$CERT_DIR/docker-client.crt" \
    -key-file "$CERT_DIR/docker-client.key" \
    -client \
    docker-client

echo "[INFO] Setting permissions..."
chmod 644 "$CERT_DIR"/*.crt
chmod 600 "$CERT_DIR"/*.key
chmod 644 "$CERT_DIR/ca/rootCA.pem"

echo "[INFO] Certificates generated successfully!"
echo ""
echo "=== Web Interface Certificates ==="
echo "Certificate: $CERT_DIR/web.crt"
echo "Key:         $CERT_DIR/web.key"
echo ""
echo "=== Docker TLS Certificates (for Whale settings) ==="
echo "CA Certificate:     $CERT_DIR/docker-ca.crt"
echo "Client Certificate: $CERT_DIR/docker-client.crt"
echo "Client Key:         $CERT_DIR/docker-client.key"
echo ""
echo "=== Root CA (import to browser) ==="
echo "Root CA: $CERT_DIR/ca/rootCA.pem"
echo ""
echo "[INFO] Copy rootCA.pem to your host machine and import it to browser to trust the certificates"

