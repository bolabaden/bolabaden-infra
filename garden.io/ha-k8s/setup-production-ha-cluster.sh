#!/bin/bash
set -euo pipefail

PRIMARY="micklethefickle.bolabaden.org"
CP_NODES=("cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
WORKERS=("cloudserver3.bolabaden.org" "blackboar.bolabaden.org")

echo "=== Production HA Kubernetes Cluster Setup ==="
echo ""

# Copy kubeadm config to primary
echo "=== Copying kubeadm config to primary node ==="
scp garden.io/ha-k8s/kubeadm-ha-config.yaml ubuntu@$PRIMARY:/tmp/kubeadm-ha-config.yaml

# Initialize primary
echo ""
echo "=== Initializing Primary Control Plane ==="
ssh ubuntu@$PRIMARY "sudo kubeadm init --config=/tmp/kubeadm-ha-config.yaml --upload-certs 2>&1 | tee /tmp/kubeadm-init.log"

# Get kubeconfig
echo ""
echo "=== Setting up kubeconfig ==="
mkdir -p ~/.kube
scp ubuntu@$PRIMARY:~/.kube/config ~/.kube/ha-cluster-config || ssh ubuntu@$PRIMARY "mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown ubuntu:ubuntu ~/.kube/config" && scp ubuntu@$PRIMARY:~/.kube/config ~/.kube/ha-cluster-config

echo ""
echo "✅ Primary control plane initialized"
echo "Next: Join additional nodes using join commands from primary"
