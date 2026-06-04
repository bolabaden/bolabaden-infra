#!/bin/bash
# Automated HA Kubernetes Cluster Setup
# This script automates the entire HA cluster setup process

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Automated HA Kubernetes Cluster Setup ==="
echo ""

# Get all node IPs
get_node_ip() {
  local node=$1
  ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$node" "hostname -I | awk '{print \$1}'" 2>&1 | head -1
}

echo "=== Step 1: Gathering Node Information ==="
PRIMARY_IP=$(get_node_ip "$PRIMARY_NODE")
CP1_IP=$(get_node_ip "${CONTROL_PLANE_NODES[1]}")
CP2_IP=$(get_node_ip "${CONTROL_PLANE_NODES[2]}")
W1_IP=$(get_node_ip "${WORKER_NODES[0]}")
W2_IP=$(get_node_ip "${WORKER_NODES[1]}")

echo "Node IPs:"
echo "  Primary: $PRIMARY_NODE ($PRIMARY_IP)"
echo "  CP1: ${CONTROL_PLANE_NODES[1]} ($CP1_IP)"
echo "  CP2: ${CONTROL_PLANE_NODES[2]} ($CP2_IP)"
echo "  Worker1: ${WORKER_NODES[0]} ($W1_IP)"
echo "  Worker2: ${WORKER_NODES[1]} ($W2_IP)"
echo ""

# Create kubeadm config
cat > "$SCRIPT_DIR/kubeadm-production-config.yaml" << KUBEADM_CONFIG
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.27.3
controlPlaneEndpoint: "$PRIMARY_NODE:6443"
etcd:
  external:
    endpoints:
      - "https://$PRIMARY_IP:2379"
      - "https://$CP1_IP:2379"
      - "https://$CP2_IP:2379"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
apiServer:
  certSANs:
    - "$PRIMARY_NODE"
    - "${CONTROL_PLANE_NODES[1]}"
    - "${CONTROL_PLANE_NODES[2]}"
    - "${WORKER_NODES[0]}"
    - "${WORKER_NODES[1]}"
    - "$PRIMARY_IP"
    - "$CP1_IP"
    - "$CP2_IP"
    - "$W1_IP"
    - "$W2_IP"
    - "127.0.0.1"
    - "10.96.0.1"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$PRIMARY_IP"
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
KUBEADM_CONFIG

echo "✅ kubeadm configuration created"
echo ""
echo "=== Configuration saved to: $SCRIPT_DIR/kubeadm-production-config.yaml ==="
echo ""
echo "Next: Initialize cluster on primary node with:"
echo "  sudo kubeadm init --config=$SCRIPT_DIR/kubeadm-production-config.yaml"
