#!/bin/bash
# Deploy all services with High Availability configuration

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
export KUBECONFIG=/tmp/kubeconfig
GARDEN_PATH=$(find /tmp/garden-install -name "garden" -type f 2>/dev/null | head -1)

echo "=== Deploying Services with HA Configuration ==="

# Deploy with HA settings
"$GARDEN_PATH" deploy --env k8s \
  --var replicas.controlPlane=3 \
  --var replicas.etcd=3 \
  --var replicas.coreDNS=3 \
  --var replicas.ingressController=3 \
  --var storage.replicationFactor=3 \
  --var antiAffinity.enabled=true \
  2>&1 | tee /tmp/garden-ha-deploy.log

echo ""
echo "=== Verifying HA Deployment ==="
kubectl get nodes
kubectl get pods --all-namespaces -o wide | head -50

echo ""
echo "✅ HA deployment complete"
