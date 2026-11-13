#!/usr/bin/env bash
# Run on every machine that will `docker login/pull/push` (your laptop, k8s nodes...).
# Makes Docker trust the self-signed cert for an IP-based registry.
# Usage: sudo ./client-trust.sh <registry-ip> <path-to-fullchain.pem>
set -euo pipefail
IP="${1:?usage: $0 <registry-ip> <fullchain.pem>}"
CRT="${2:?usage: $0 <registry-ip> <fullchain.pem>}"
install -d "/etc/docker/certs.d/${IP}"
install -m 644 "$CRT" "/etc/docker/certs.d/${IP}/ca.crt"
echo "Docker now trusts ${IP}. (No Docker restart needed.)"
# containerd / k8s nodes: also configure /etc/containerd/certs.d/${IP}/hosts.toml with ca = "..."
