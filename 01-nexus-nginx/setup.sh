#!/usr/bin/env bash
# Usage: SERVER_IP=1.2.3.4 ./setup.sh
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] && set -a && . ./.env && set +a
SERVER_IP="${SERVER_IP:?Set SERVER_IP (env or .env)}"

mkdir -p certs nexus-data

# ---------- IP MODE: self-signed cert with IP SAN ----------
if [ ! -f certs/fullchain.pem ]; then
  openssl req -x509 -newkey rsa:4096 -nodes -days 825 \
    -keyout certs/privkey.pem -out certs/fullchain.pem \
    -subj "/CN=${SERVER_IP}" \
    -addext "subjectAltName=IP:${SERVER_IP}"
  echo "Self-signed cert created for ${SERVER_IP}"
fi

# ---------- DOMAIN MODE (Let's Encrypt) - uncomment to use ----------
# DOMAIN="nginx-nexus.example.com"
# sudo apt install -y certbot
# sudo certbot certonly --standalone -d "$DOMAIN"      # port 80 must be free & DNS set
# sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem certs/
# sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem  certs/
# sudo chown -R "$USER":"$USER" certs/

# Nexus runs as uid 200 (better than chmod 777)
sudo chown -R 200:200 nexus-data

docker compose up -d
echo
echo "Wait ~2 min, then open: https://${SERVER_IP}/"
echo "Admin password:  sudo cat nexus-data/admin.password"
echo "Docker clients:  sudo scripts/client-trust.sh ${SERVER_IP} certs/fullchain.pem"
