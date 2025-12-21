#!/bin/bash
set -euo pipefail

cd /home/ubuntu/my-media-stack/garden.io

echo "=== Deploying All Services with HA Configuration ==="
echo ""

# Get kubeconfig from primary
PRIMARY="micklethefickle.bolabaden.org"
scp ubuntu@$PRIMARY:~/.kube/config ~/.kube/ha-cluster-config 2>/dev/null || echo "⚠️  Kubeconfig not available"

export KUBECONFIG=~/.kube/ha-cluster-config

# Verify cluster
echo "=== Verifying Cluster ==="
kubectl get nodes
kubectl get pods -n kube-system | head -10

# Deploy with Garden
GARDEN_PATH=$(find /tmp/garden-install -name "garden" -type f 2>/dev/null | head -1)
if [ -n "$GARDEN_PATH" ]; then
    export PATH="$(dirname $GARDEN_PATH):$PATH"
    echo ""
    echo "=== Deploying Services with Garden ==="
    garden deploy --env ha-k8s 2>&1 | tee /tmp/garden-ha-deploy.log
else
    echo "⚠️  Garden CLI not found"
fi

echo ""
echo "✅ HA deployment initiated"
