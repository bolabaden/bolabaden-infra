#!/bin/bash
set -euo pipefail

# Script to fix etcd IP mismatch issue
# etcd was initialized with old IP but k3s is configured for Tailscale IP

PRIMARY_NODE="${1:-micklethefickle.bolabaden.org}"

echo "=== Fixing etcd IP Mismatch ==="
echo "Primary: $PRIMARY_NODE"
echo ""
echo "WARNING: This will reset etcd and cause data loss!"
echo "This is acceptable for a new cluster setup."
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<'EOF'
set -e

echo "=== Stopping k3s ==="
sudo systemctl stop k3s

echo "=== Backing up etcd data ==="
sudo mkdir -p /var/lib/rancher/k3s/server/db-backup
if [ -d /var/lib/rancher/k3s/server/db/etcd ]; then
    sudo mv /var/lib/rancher/k3s/server/db/etcd /var/lib/rancher/k3s/server/db-backup/etcd-$(date +%Y%m%d-%H%M%S)
    echo "✓ etcd data backed up"
fi

echo "=== Removing old etcd member data ==="
sudo rm -rf /var/lib/rancher/k3s/server/db/etcd/member

echo "=== Starting k3s (will reinitialize etcd) ==="
sudo systemctl start k3s

echo "=== Waiting for k3s to start ==="
sleep 10

echo "=== Checking k3s status ==="
sudo systemctl status k3s --no-pager | head -15

echo ""
echo "=== Waiting for API to be ready ==="
for i in {1..60}; do
    if export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get nodes &>/dev/null; then
        echo "✓ k3s API is ready!"
        kubectl get nodes
        break
    fi
    echo "  Attempt $i/60..."
    sleep 5
done
EOF

echo ""
echo "=== etcd IP Mismatch Fixed ==="
echo "k3s should now be running with etcd initialized with the correct IP"

