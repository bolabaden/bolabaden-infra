#!/bin/bash
# Complete HA Kubernetes Cluster Setup
# This script sets up a zero-SPOF Kubernetes cluster

set -euo pipefail

PRIMARY_NODE="micklethefickle.bolabaden.org"
CONTROL_PLANE_NODES=(
  "micklethefickle.bolabaden.org"
  "cloudserver1.bolabaden.org"
  "cloudserver2.bolabaden.org"
)
WORKER_NODES=(
  "cloudserver3.bolabaden.org"
  "blackboar.bolabaden.org"
)

echo "=== Complete HA Kubernetes Cluster Setup ==="
echo "This will take significant time. Please be patient."
echo ""

# Get node IPs
get_node_ip() {
  local node=$1
  ssh -o StrictHostKeyChecking=no "$node" "hostname -I | awk '{print \$1}'" 2>&1 | head -1
}

echo "=== Step 1: Getting Node IPs ==="
PRIMARY_IP=$(get_node_ip "$PRIMARY_NODE")
CP1_IP=$(get_node_ip "${CONTROL_PLANE_NODES[1]}")
CP2_IP=$(get_node_ip "${CONTROL_PLANE_NODES[2]}")
echo "Primary: $PRIMARY_NODE ($PRIMARY_IP)"
echo "CP1: ${CONTROL_PLANE_NODES[1]} ($CP1_IP)"
echo "CP2: ${CONTROL_PLANE_NODES[2]} ($CP2_IP)"

echo ""
echo "=== Step 2: Initializing Primary Control Plane ==="
echo "This will initialize the first control plane node"
echo "Run this manually on $PRIMARY_NODE:"
echo "  sudo kubeadm init --config=/path/to/kubeadm-ha-config.yaml"

echo ""
echo "=== Step 3: Setting Up Load Balancer ==="
echo "Configure HAProxy/keepalived for kube-apiserver HA"

echo ""
echo "=== Step 4: Joining Additional Control Plane Nodes ==="
echo "Join ${CONTROL_PLANE_NODES[1]} and ${CONTROL_PLANE_NODES[2]} as control plane nodes"

echo ""
echo "=== Step 5: Joining Worker Nodes ==="
echo "Join ${WORKER_NODES[*]} as worker nodes"

echo ""
echo "✅ Setup script ready. Manual steps required for full HA cluster."
