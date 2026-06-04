#!/bin/bash
set -euo pipefail

PRIMARY_NODE="micklethefickle.bolabaden.org"
CONTROL_PLANE_NODES=("cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
WORKER_NODES=("cloudserver3.bolabaden.org" "blackboar.bolabaden.org")

echo "=== Getting k3s token from primary node ==="
TOKEN=$(ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" "sudo cat /var/lib/rancher/k3s/server/node-token" 2>&1 | head -1)
echo "Token obtained: ${TOKEN:0:20}..."

echo ""
echo "=== Joining control plane nodes ==="
for node in "${CONTROL_PLANE_NODES[@]}"; do
    echo "Joining $node as control plane..."
    ssh -o StrictHostKeyChecking=no "$node" <<EOF
set -e
sudo mkdir -p /etc/rancher/k3s
cat > /tmp/k3s-config.yaml <<CONFIG
server: https://${PRIMARY_NODE}:6443
token: ${TOKEN}
CONFIG
sudo mv /tmp/k3s-config.yaml /etc/rancher/k3s/config.yaml

# Install k3s if not already installed
if [ ! -f /usr/local/bin/k3s ]; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server' K3S_URL=https://${PRIMARY_NODE}:6443 K3S_TOKEN=${TOKEN} sh -
else
    # Create systemd service if it doesn't exist
    if ! systemctl list-units | grep -q k3s.service; then
        sudo mkdir -p /etc/systemd/system
        cat > /tmp/k3s.service <<SERVICE
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
        sudo mv /tmp/k3s.service /etc/systemd/system/k3s.service
        sudo systemctl daemon-reload
        sudo systemctl enable k3s
    fi
    sudo systemctl restart k3s || sudo systemctl start k3s
fi
EOF
    echo "  ✓ $node configured"
done

echo ""
echo "=== Verifying worker nodes ==="
for node in "${WORKER_NODES[@]}"; do
    echo "Verifying $node..."
    ssh -o StrictHostKeyChecking=no "$node" <<EOF
if ! systemctl is-active --quiet k3s-agent; then
    curl -sfL https://get.k3s.io | K3S_URL=https://${PRIMARY_NODE}:6443 K3S_TOKEN=${TOKEN} sh -
fi
EOF
    echo "  ✓ $node verified"
done

echo ""
echo "=== Waiting for nodes to join ==="
sleep 30

echo ""
echo "=== Final node status ==="
ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get nodes -o wide"

echo ""
echo "=== Done ==="

