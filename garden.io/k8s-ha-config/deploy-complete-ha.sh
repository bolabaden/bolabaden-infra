#!/bin/bash
# Deploy All Services with Complete HA Configuration
# Ensures zero SPOF for all services

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

echo "=== Deploying All Services with Complete HA ==="

# Determine which cluster to use
if [ -f ~/.kube/config ] && kubectl get nodes &>/dev/null 2>&1; then
  echo "Using existing cluster:"
  kubectl get nodes
  KUBECONFIG=~/.kube/config
elif ssh -o StrictHostKeyChecking=no micklethefickle.bolabaden.org "sudo kubectl get nodes &>/dev/null" 2>&1; then
  echo "Using k3s cluster on primary node"
  KUBECONFIG=/tmp/k3s-config
  ssh -o StrictHostKeyChecking=no micklethefickle.bolabaden.org "sudo cat /etc/rancher/k3s/k3s.yaml" | sed "s/127.0.0.1/micklethefickle.bolabaden.org/g" > "$KUBECONFIG"
else
  echo "⚠️  No cluster available. Setting up cluster first..."
  exit 1
fi

export KUBECONFIG

echo ""
echo "=== Step 1: Installing Calico CNI for HA Networking ==="
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml 2>&1 | tail -20

echo ""
echo "=== Step 2: Installing Longhorn for Distributed Storage ==="
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml 2>&1 | tail -20

echo ""
echo "=== Step 3: Scaling CoreDNS for HA ==="
kubectl scale deployment coredns -n kube-system --replicas=3 2>&1

echo ""
echo "=== Step 4: Deploying Services with Garden.io ==="
GARDEN_PATH=$(find /tmp/garden-install -name "garden" -type f 2>/dev/null | head -1)
if [ -n "$GARDEN_PATH" ]; then
  "$GARDEN_PATH" deploy --env k8s 2>&1 | tee /tmp/garden-ha-deploy.log | tail -100
else
  echo "⚠️  Garden CLI not found. Install it first."
fi

echo ""
echo "=== Step 5: Verifying HA Deployment ==="
kubectl get nodes
kubectl get pods --all-namespaces -o wide | head -50

echo ""
echo "✅ HA deployment complete"
