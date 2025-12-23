#!/bin/bash
set -euo pipefail

PRIMARY_IP="${1:-}"
TOKEN="${2:-}"

if [ -z "$PRIMARY_IP" ] || [ -z "$TOKEN" ]; then
    echo "Usage: $0 <primary-ip> <token>"
    exit 1
fi

echo "=== Installing k3s as HA control plane node ==="
echo "Primary IP: $PRIMARY_IP"
echo "Token: ${TOKEN:0:20}..."

# Create config directory
sudo mkdir -p /etc/rancher/k3s

# Write config file
cat > /tmp/k3s-config.yaml <<EOF
server: https://${PRIMARY_IP}:6443
token: ${TOKEN}
EOF
sudo mv /tmp/k3s-config.yaml /etc/rancher/k3s/config.yaml

# Install k3s
echo "=== Running k3s installer ==="
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --server https://${PRIMARY_IP}:6443" K3S_TOKEN="${TOKEN}" sh -

# Wait for service to start
echo "=== Waiting for k3s service to start ==="
sleep 10

# Check service status
if sudo systemctl is-active --quiet k3s; then
    echo "✓ k3s service is running"
    sudo systemctl status k3s --no-pager | head -10
else
    echo "✗ k3s service failed to start"
    sudo journalctl -u k3s.service --no-pager | tail -20
    exit 1
fi

echo "=== Installation complete ==="

