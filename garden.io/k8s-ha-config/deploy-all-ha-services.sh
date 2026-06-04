#!/bin/bash
# Deploy All Services with High Availability
# Ensures zero SPOF for all services

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

export KUBECONFIG=/tmp/kubeconfig
GARDEN_PATH=$(find /tmp/garden-install -name "garden" -type f 2>/dev/null | head -1) || GARDEN_PATH="garden"

echo "=== Deploying All Services with HA Configuration ==="

# Deploy with HA settings
"$GARDEN_PATH" deploy --env k8s \
  --var replicas.defaultService=3 \
  --var antiAffinity.enabled=true \
  --var podDisruptionBudgets.enabled=true \
  2>&1 | tee /tmp/garden-ha-deploy.log

echo ""
echo "=== Verifying HA Deployment ==="
kubectl get nodes
kubectl get pods --all-namespaces -o wide | grep -v "kube-system" | head -50

echo ""
echo "=== Checking Service Replication ==="
kubectl get deployments --all-namespaces -o wide | grep -v "kube-system" | head -30

echo ""
echo "✅ HA deployment complete"
