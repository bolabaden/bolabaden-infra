#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== High Availability Kubernetes Deployment ==="
echo ""

cd "$PROJECT_ROOT/garden.io"

# Check Garden CLI
if ! command -v garden &> /dev/null; then
    GARDEN_PATH=$(find /tmp/garden-install -name "garden" -type f 2>/dev/null | head -1)
    if [ -n "$GARDEN_PATH" ]; then
        export PATH="$(dirname $GARDEN_PATH):$PATH"
    else
        echo "❌ Garden CLI not found"
        exit 1
    fi
fi

# Deploy with HA configuration
echo "=== Deploying Services with HA Configuration ==="
garden deploy --env ha-k8s --force 2>&1 | tee /tmp/garden-ha-deploy.log

echo ""
echo "=== Verifying HA Deployment ==="
kubectl get nodes
kubectl get pods --all-namespaces -o wide | grep -v "kube-system" | head -30

echo ""
echo "✅ HA deployment initiated"
