#!/bin/bash
set -euo pipefail

# Script to configure k3s nodes to use Tailscale for networking
# This follows canonical k3s + Tailscale integration patterns

NODE_NAME="${1:-}"
TAILSCALE_AUTH_KEY="${2:-}"

if [ -z "$NODE_NAME" ]; then
    echo "Usage: $0 <node-name> [tailscale-auth-key]"
    echo "Example: $0 blackboar.bolabaden.org"
    exit 1
fi

echo "=== Configuring $NODE_NAME for Tailscale + k3s ==="

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")

if [ -z "$TAILSCALE_IP" ]; then
    echo "Tailscale not connected. Connecting..."
    
    if [ -n "$TAILSCALE_AUTH_KEY" ]; then
        sudo tailscale up --authkey="$TAILSCALE_AUTH_KEY" --accept-routes --accept-dns=false
    else
        echo "No auth key provided. Please run: sudo tailscale up --accept-routes --accept-dns=false"
        echo "Then re-run this script."
        exit 1
    fi
    
    sleep 5
    TAILSCALE_IP=$(tailscale ip -4)
fi

echo "Tailscale IP: $TAILSCALE_IP"

# Check if k3s is installed
if [ ! -f /usr/local/bin/k3s ]; then
    echo "k3s not found. Please install k3s first."
    exit 1
fi

# Configure k3s to use Tailscale
echo "=== Configuring k3s to use Tailscale ==="
sudo mkdir -p /etc/rancher/k3s

# Check if this is a server or agent
if systemctl is-active --quiet k3s 2>/dev/null || systemctl is-active --quiet k3s-server 2>/dev/null; then
    # Server node
    cat <<EOF | sudo tee /etc/rancher/k3s/config.yaml
bind-address: 0.0.0.0
advertise-address: ${TAILSCALE_IP}
node-ip: ${TAILSCALE_IP}
node-external-ip: ${TAILSCALE_IP}
service-cidr: 10.43.0.0/16
cluster-cidr: 10.42.0.0/16
flannel-iface: tailscale0
EOF
    echo "Server configuration written. Restarting k3s..."
    sudo systemctl restart k3s || sudo systemctl restart k3s-server
elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
    # Agent node - preserve existing server config
    if [ -f /etc/rancher/k3s/config.yaml ]; then
        # Update existing config
        sudo sed -i "s/advertise-address:.*/advertise-address: ${TAILSCALE_IP}/" /etc/rancher/k3s/config.yaml || true
        sudo sed -i "s/node-ip:.*/node-ip: ${TAILSCALE_IP}/" /etc/rancher/k3s/config.yaml || true
        sudo sed -i "s/node-external-ip:.*/node-external-ip: ${TAILSCALE_IP}/" /etc/rancher/k3s/config.yaml || true
        echo "flannel-iface: tailscale0" | sudo tee -a /etc/rancher/k3s/config.yaml
    else
        cat <<EOF | sudo tee /etc/rancher/k3s/config.yaml
node-ip: ${TAILSCALE_IP}
node-external-ip: ${TAILSCALE_IP}
flannel-iface: tailscale0
EOF
    fi
    echo "Agent configuration written. Restarting k3s-agent..."
    sudo systemctl restart k3s-agent
else
    echo "k3s service not found. Please install k3s first."
    exit 1
fi

# Ensure Tailscale DNS doesn't override Kubernetes DNS
echo "=== Configuring Tailscale DNS ==="
sudo tailscale set --accept-dns=false

echo "=== Configuration complete ==="
echo "Tailscale IP: $TAILSCALE_IP"
echo "k3s configured to use Tailscale interface"

