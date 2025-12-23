#!/bin/bash
set -euo pipefail

PRIMARY_IP="${1:-}"
TOKEN="${2:-}"

if [ -z "$PRIMARY_IP" ] || [ -z "$TOKEN" ]; then
    echo "Usage: $0 <primary-ip> <token>"
    exit 1
fi

echo "=== Creating k3s systemd service ==="

# Ensure k3s is installed
if [ ! -f /usr/local/bin/k3s ]; then
    echo "Installing k3s..."
    curl -sfL https://get.k3s.io | sh -
fi

# Create config
sudo mkdir -p /etc/rancher/k3s
cat > /tmp/k3s-config.yaml <<EOF
server: https://${PRIMARY_IP}:6443
token: ${TOKEN}
EOF
sudo mv /tmp/k3s-config.yaml /etc/rancher/k3s/config.yaml

# Create systemd service
sudo tee /etc/systemd/system/k3s.service > /dev/null <<'SERVICE'
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/k3s server
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE

# Reload and start
sudo systemctl daemon-reload
sudo systemctl enable k3s
sudo systemctl start k3s

echo "=== Waiting for service to start ==="
sleep 15

if sudo systemctl is-active --quiet k3s; then
    echo "✓ k3s service is running"
    sudo systemctl status k3s --no-pager | head -10
else
    echo "✗ k3s service failed"
    sudo journalctl -u k3s.service --no-pager | tail -30
    exit 1
fi

