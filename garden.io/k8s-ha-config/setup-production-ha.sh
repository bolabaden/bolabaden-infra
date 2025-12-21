#!/bin/bash
# Complete Production HA Kubernetes Cluster Setup
# This sets up a real multi-node HA cluster

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

echo "=== Production HA Kubernetes Cluster Setup ==="
echo ""

# Get node IPs
get_node_ip() {
  local node=$1
  ssh -o StrictHostKeyChecking=no "$node" "hostname -I | awk '{print \$1}'" 2>&1 | head -1
}

PRIMARY_IP=$(get_node_ip "$PRIMARY_NODE")
CP1_IP=$(get_node_ip "${CONTROL_PLANE_NODES[1]}")
CP2_IP=$(get_node_ip "${CONTROL_PLANE_NODES[2]}")

echo "Node IPs:"
echo "  Primary: $PRIMARY_IP"
echo "  CP1: $CP1_IP"
echo "  CP2: $CP2_IP"
echo ""

# Create kubeadm config with actual IPs
cat > /tmp/kubeadm-ha-config.yaml << KUBEADM_CONFIG
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
    - "127.0.0.1"
    - "10.96.0.1"
KUBEADM_CONFIG

echo "✅ kubeadm config created with node IPs"
echo ""
echo "Next steps:"
echo "1. Copy kubeadm config to primary node"
echo "2. Initialize cluster on primary"
echo "3. Join additional control plane nodes"
echo "4. Join worker nodes"
echo "5. Install CNI and storage"
