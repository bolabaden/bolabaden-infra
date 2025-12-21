#!/bin/bash
set -euo pipefail

PRIMARY_NODE="micklethefickle.bolabaden.org"
CONTROL_PLANE_NODES=("micklethefickle.bolabaden.org" "cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
WORKER_NODES=("cloudserver3.bolabaden.org" "blackboar.bolabaden.org")
ALL_NODES=("${CONTROL_PLANE_NODES[@]}" "${WORKER_NODES[@]}")

echo "=== Complete HA Kubernetes Cluster Setup ==="
echo "Primary: $PRIMARY_NODE"
echo "Control Plane: ${CONTROL_PLANE_NODES[*]}"
echo "Workers: ${WORKER_NODES[*]}"
echo ""

# Function to run command on node
run_on_node() {
    local node=$1
    shift
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@${node} "$@"
}

# Install Kubernetes on all nodes
install_k8s_all_nodes() {
    echo "=== Installing Kubernetes on All Nodes ==="
    for node in "${ALL_NODES[@]}"; do
        echo "Installing on $node..."
        run_on_node "$node" "sudo bash -c '
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl gpg
            curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.27/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /\" | tee /etc/apt/sources.list.d/kubernetes.list
            apt-get update
            apt-get install -y kubelet kubeadm kubectl containerd
            apt-mark hold kubelet kubeadm kubectl
            systemctl enable --now containerd
            systemctl enable --now kubelet
        '" || echo "⚠️  Failed on $node"
    done
}

# Initialize primary control plane
init_primary() {
    echo "=== Initializing Primary Control Plane ==="
    run_on_node "$PRIMARY_NODE" "sudo kubeadm init --config=/tmp/cluster-config.yaml --upload-certs" || true
}

install_k8s_all_nodes
echo ""
echo "✅ Kubernetes installation initiated on all nodes"
echo "Next: Initialize primary control plane and join nodes"
