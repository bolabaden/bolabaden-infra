#!/bin/bash
set -euo pipefail

# Script to set up HA k3s control plane with zero SPOF
# Requires 3+ server nodes for etcd quorum

PRIMARY_NODE="${1:-micklethefickle.bolabaden.org}"
SERVER_NODES=("${@:2}")

if [ ${#SERVER_NODES[@]} -lt 2 ]; then
    echo "ERROR: Need at least 3 total server nodes (1 primary + 2 additional) for HA"
    echo "Usage: $0 <primary-node> <server-node-1> <server-node-2> [server-node-3...]"
    exit 1
fi

echo "=== Setting up HA k3s Control Plane ==="
echo "Primary: $PRIMARY_NODE"
echo "Additional servers: ${SERVER_NODES[*]}"

# Get primary node Tailscale IP and token
PRIMARY_TS_IP=$(ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" "tailscale ip -4" 2>&1)
TOKEN=$(ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" "sudo cat /var/lib/rancher/k3s/server/node-token" 2>&1 | head -1)

echo "Primary Tailscale IP: $PRIMARY_TS_IP"
echo "Token: ${TOKEN}"

# Configure additional server nodes
for node in "${SERVER_NODES[@]}"; do
    echo ""
    echo "=== Configuring $node as HA server node ==="
    
    # Get node's Tailscale IP
    NODE_TS_IP=$(ssh -o StrictHostKeyChecking=no "$node" "tailscale ip -4" 2>&1)
    
    if [ -z "$NODE_TS_IP" ]; then
        echo "ERROR: $node is not connected to Tailscale"
        exit 1
    fi
    
    echo "Node Tailscale IP: $NODE_TS_IP"
    
    # Configure k3s as server node joining the cluster
    ssh -o StrictHostKeyChecking=no "$node" <<EOF
set -e
sudo mkdir -p /etc/rancher/k3s
cat <<CONFIG | sudo tee /etc/rancher/k3s/config.yaml
server: https://${PRIMARY_TS_IP}:6443
token: ${TOKEN}
node-ip: ${NODE_TS_IP}
node-external-ip: ${NODE_TS_IP}
flannel-iface: tailscale0
disable-apiserver-lb: true
EOF

# Install k3s as server if not already installed
if [ ! -f /usr/local/bin/k3s ]; then
    echo "Installing k3s server..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server' sh -
else
    echo "k3s already installed, restarting..."
    sudo systemctl restart k3s || sudo systemctl restart k3s-server
fi

# Ensure Tailscale DNS doesn't override
sudo tailscale set --accept-dns=false

echo "Server node $node configured"
EOF
    
    echo "Waiting for $node to join cluster..."
    sleep 15
done

echo ""
echo "=== HA Control Plane Setup Complete ==="
echo "Verifying cluster status..."

ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes -o wide
echo ""
echo "=== etcd Cluster Status ==="
kubectl get pods -n kube-system -l component=etcd -o wide
EOF

echo ""
echo "=== Next Steps ==="
echo "1. Verify all server nodes are Ready"
echo "2. Verify etcd pods are running on multiple nodes"
echo "3. Configure Longhorn for replication"
echo "4. Scale all services to 3+ replicas"

