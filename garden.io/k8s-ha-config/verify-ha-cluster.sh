#!/bin/bash
# Complete HA Cluster Verification
# Ensures zero SPOF

set -euo pipefail

KUBECONFIG=${KUBECONFIG:-/tmp/k3s-kubeconfig.yaml}

echo "=== Complete HA Cluster Verification ==="
echo ""

echo "=== 1. Node Health ==="
kubectl --insecure-skip-tls-verify get nodes -o wide
NODE_COUNT=$(kubectl --insecure-skip-tls-verify get nodes --no-headers | wc -l)
READY_NODES=$(kubectl --insecure-skip-tls-verify get nodes --no-headers | grep -c Ready || echo "0")
echo "Total Nodes: $NODE_COUNT"
echo "Ready Nodes: $READY_NODES"
if [ "$NODE_COUNT" -ge 5 ] && [ "$READY_NODES" -eq "$NODE_COUNT" ]; then
  echo "✅ All nodes healthy"
else
  echo "❌ Node health issue"
fi

echo ""
echo "=== 2. Control Plane Components ==="
kubectl --insecure-skip-tls-verify get pods -n kube-system | grep -E "kube-apiserver|kube-scheduler|kube-controller-manager|etcd" || echo "k3s uses embedded components"

echo ""
echo "=== 3. CoreDNS HA ==="
COREDNS_REPLICAS=$(kubectl --insecure-skip-tls-verify get deployment coredns -n kube-system -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
COREDNS_READY=$(kubectl --insecure-skip-tls-verify get deployment coredns -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo "Desired Replicas: $COREDNS_REPLICAS"
echo "Ready Replicas: $COREDNS_READY"
if [ "$COREDNS_REPLICAS" -ge 3 ] && [ "$COREDNS_READY" -ge 2 ]; then
  echo "✅ CoreDNS HA configured"
else
  echo "⚠️  CoreDNS needs more replicas"
fi

echo ""
echo "=== 4. Calico CNI ==="
CALICO_NODES=$(kubectl --insecure-skip-tls-verify get daemonset calico-node -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
CALICO_DESIRED=$(kubectl --insecure-skip-tls-verify get daemonset calico-node -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
echo "Calico Nodes Ready: $CALICO_NODES/$CALICO_DESIRED"
if [ "$CALICO_NODES" -eq "$CALICO_DESIRED" ] && [ "$CALICO_NODES" -ge 2 ]; then
  echo "✅ Calico HA configured"
else
  echo "⚠️  Calico needs attention"
fi

echo ""
echo "=== 5. Longhorn Storage ==="
LH_MANAGERS=$(kubectl --insecure-skip-tls-verify get daemonset longhorn-manager -n longhorn-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
LH_DESIRED=$(kubectl --insecure-skip-tls-verify get daemonset longhorn-manager -n longhorn-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
echo "Longhorn Managers Ready: $LH_MANAGERS/$LH_DESIRED"
if [ "$LH_MANAGERS" -eq "$LH_DESIRED" ] && [ "$LH_MANAGERS" -ge 2 ]; then
  echo "✅ Longhorn HA configured"
else
  echo "⚠️  Longhorn needs attention"
fi

echo ""
echo "=== 6. Metrics Server ==="
MS_READY=$(kubectl --insecure-skip-tls-verify get deployment metrics-server -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$MS_READY" -ge 1 ]; then
  echo "✅ Metrics Server ready"
else
  echo "⚠️  Metrics Server needs attention"
fi

echo ""
echo "=== 7. Pod Disruption Budgets ==="
kubectl --insecure-skip-tls-verify get poddisruptionbudgets --all-namespaces 2>&1 | head -10

echo ""
echo "=== Summary ==="
echo "Nodes: $READY_NODES/$NODE_COUNT"
echo "CoreDNS: $COREDNS_READY/$COREDNS_REPLICAS"
echo "Calico: $CALICO_NODES/$CALICO_DESIRED"
echo "Longhorn: $LH_MANAGERS/$LH_DESIRED"
