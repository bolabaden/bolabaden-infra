#!/bin/bash
set -euo pipefail

# Script to fix k3s startup issues and connect nodes for HA
# This addresses both k3s API availability and node connectivity

PRIMARY_NODE="${1:-micklethefickle.bolabaden.org}"
TOKEN="${2:-}"

if [ -z "$TOKEN" ]; then
    echo "ERROR: Token required"
    echo "Usage: $0 <primary-node> <token>"
    exit 1
fi

echo "=== Fixing k3s and Connecting Nodes for HA ==="
echo "Primary: $PRIMARY_NODE"
echo ""

# Step 1: Check and fix k3s on primary
echo "=== Step 1: Checking Primary Node k3s ==="
PRIMARY_TS_IP=$(ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" "tailscale ip -4" 2>&1)
PRIMARY_REG_IP=$(ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" "hostname -I | awk '{print \$1}'" 2>&1)

echo "Primary Tailscale IP: $PRIMARY_TS_IP"
echo "Primary Regular IP: $PRIMARY_REG_IP"

# Check if k3s is running
ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
set -e

# Check k3s status
if ! sudo systemctl is-active --quiet k3s; then
    echo "k3s not running, checking config..."
    
    # Ensure config exists
    sudo mkdir -p /etc/rancher/k3s
    
    # Update config with both IPs for compatibility
    cat <<CONFIG | sudo tee /etc/rancher/k3s/config.yaml
bind-address: 0.0.0.0
advertise-address: ${PRIMARY_TS_IP}
tls-san:
  - ${PRIMARY_TS_IP}
  - ${PRIMARY_REG_IP}
  - micklethefickle.bolabaden.org
node-ip: ${PRIMARY_TS_IP},${PRIMARY_REG_IP}
node-external-ip: ${PRIMARY_TS_IP}
flannel-iface: tailscale0
service-cidr: 10.43.0.0/16
cluster-cidr: 10.42.0.0/16
disable-apiserver-lb: true
CONFIG
    
    echo "Starting k3s..."
    sudo systemctl start k3s
    sleep 10
fi

# Wait for API to be ready
echo "Waiting for k3s API..."
for i in {1..60}; do
    if export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get nodes &>/dev/null; then
        echo "✓ k3s API is ready"
        break
    fi
    echo "  Attempt \$i/60..."
    sleep 5
done
EOF

echo ""
echo "=== Step 2: Connecting Worker Nodes (Using Direct IPs Temporarily) ==="

# For now, use direct IPs until Tailscale is connected
# We'll configure them to use the primary's regular IP
# NOTE: blackboar excluded due to reliability issues
WORKER_NODES=("cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")

for node in "${WORKER_NODES[@]}"; do
    echo ""
    echo "--- Configuring $node ---"
    
    # Get node's regular IP
    NODE_IP=$(ssh -o StrictHostKeyChecking=no "$node" "hostname -I | awk '{print \$1}'" 2>&1 || echo "")
    
    if [ -z "$NODE_IP" ]; then
        echo "⚠️  Could not get IP for $node, skipping..."
        continue
    fi
    
    echo "Node IP: $NODE_IP"
    
    # Configure as worker node (agent mode)
    ssh -o StrictHostKeyChecking=no "$node" <<EOF
set -e
sudo mkdir -p /etc/rancher/k3s

# Use primary's regular IP for now (will switch to Tailscale later)
cat <<CONFIG | sudo tee /etc/rancher/k3s/config.yaml
server: https://${PRIMARY_REG_IP}:6443
token: ${TOKEN}
node-ip: ${NODE_IP}
flannel-iface: eth0
disable-apiserver-lb: true
CONFIG

# Install k3s agent if not installed
if [ ! -f /usr/local/bin/k3s ]; then
    echo "Installing k3s agent..."
    curl -sfL https://get.k3s.io | K3S_URL=https://${PRIMARY_REG_IP}:6443 K3S_TOKEN=${TOKEN} sh -
else
    echo "k3s already installed, restarting agent..."
    sudo systemctl restart k3s-agent || sudo systemctl restart k3s
fi

echo "✓ $node configured as worker"
EOF
    
    echo "Waiting for $node to join..."
    sleep 10
done

echo ""
echo "=== Step 3: Verifying Cluster ==="

ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "Nodes:"
kubectl get nodes -o wide || echo "API not ready yet"
echo ""
echo "System Pods:"
kubectl get pods -n kube-system -o wide | head -10 || echo "API not ready yet"
EOF

echo ""
echo "=== Next Steps ==="
echo "1. Once Tailscale is connected on all nodes, update configs to use Tailscale IPs"
echo "2. Add additional server nodes for HA control plane"
echo "3. Run implement-zero-spof.sh to configure all HA services"

