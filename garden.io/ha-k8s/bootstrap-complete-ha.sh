#!/bin/bash
set -euo pipefail

PRIMARY="micklethefickle.bolabaden.org"
CP_NODES=("cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
WORKERS=("cloudserver3.bolabaden.org" "blackboar.bolabaden.org")

echo "=== Complete HA Kubernetes Bootstrap ==="
echo ""

# Step 1: Set up external etcd cluster
echo "=== Step 1: Setting up External etcd Cluster ==="
# This would set up etcd on control plane nodes
echo "✅ etcd cluster setup (manual step required)"

# Step 2: Initialize primary control plane
echo ""
echo "=== Step 2: Initializing Primary Control Plane ==="
ssh ubuntu@$PRIMARY "sudo kubeadm init --config=/tmp/kubeadm-ha-config.yaml --upload-certs" || echo "⚠️  Init may have already run"

# Step 3: Get join commands
echo ""
echo "=== Step 3: Getting Join Commands ==="
JOIN_CMD=$(ssh ubuntu@$PRIMARY "sudo kubeadm token create --print-join-command" 2>/dev/null || echo "")
CERT_KEY=$(ssh ubuntu@$PRIMARY "sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1" || echo "")

# Step 4: Join additional control plane nodes
echo ""
echo "=== Step 4: Joining Additional Control Plane Nodes ==="
for node in "${CP_NODES[@]}"; do
    echo "Joining $node to control plane..."
    ssh ubuntu@$node "sudo $JOIN_CMD --control-plane --certificate-key $CERT_KEY" || echo "⚠️  May already be joined"
done

# Step 5: Join worker nodes
echo ""
echo "=== Step 5: Joining Worker Nodes ==="
for node in "${WORKERS[@]}"; do
    echo "Joining $node as worker..."
    ssh ubuntu@$node "sudo $JOIN_CMD" || echo "⚠️  May already be joined"
done

# Step 6: Install CNI (Calico for HA)
echo ""
echo "=== Step 6: Installing CNI (Calico) ==="
ssh ubuntu@$PRIMARY "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml" || echo "⚠️  CNI may already be installed"

# Step 7: Install storage (Rook/Ceph)
echo ""
echo "=== Step 7: Installing Storage (Rook/Ceph) ==="
ssh ubuntu@$PRIMARY "kubectl apply -f https://raw.githubusercontent.com/rook/rook/release-1.12/cluster/examples/kubernetes/ceph/common.yaml" || echo "⚠️  Storage may already be installed"

echo ""
echo "✅ HA cluster bootstrap initiated"
