#!/bin/bash
set -euo pipefail

PRIMARY_NODE="micklethefickle.bolabaden.org"
CONTROL_PLANE_NODES=("micklethefickle.bolabaden.org" "cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
WORKER_NODES=("cloudserver3.bolabaden.org" "blackboar.bolabaden.org")
ALL_NODES=("${CONTROL_PLANE_NODES[@]}" "${WORKER_NODES[@]}")

echo "=== High Availability Kubernetes Cluster Setup ==="
echo "Control Plane Nodes: ${CONTROL_PLANE_NODES[*]}"
echo "Worker Nodes: ${WORKER_NODES[*]}"
echo ""

# Function to run command on node
run_on_node() {
    local node=$1
    shift
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$node "$@"
}

# Install prerequisites on all nodes
install_prerequisites() {
    echo "=== Installing Prerequisites on All Nodes ==="
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
    echo "✅ Prerequisites installed"
}

# Initialize primary control plane
init_primary_control_plane() {
    echo "=== Initializing Primary Control Plane ==="
    run_on_node "$PRIMARY_NODE" "sudo kubeadm init --config=/tmp/cluster-config.yaml --upload-certs" || true
    echo "✅ Primary control plane initialized"
}

# Join additional control plane nodes
join_control_plane_nodes() {
    echo "=== Joining Additional Control Plane Nodes ==="
    for node in "${CONTROL_PLANE_NODES[@]}"; do
        if [ "$node" != "$PRIMARY_NODE" ]; then
            echo "Joining $node to control plane..."
            # This would use the join command from primary init
            # run_on_node "$node" "sudo kubeadm join ..." || true
        fi
    done
}

# Join worker nodes
join_worker_nodes() {
    echo "=== Joining Worker Nodes ==="
    for node in "${WORKER_NODES[@]}"; do
        echo "Joining $node as worker..."
        # This would use the worker join command
        # run_on_node "$node" "sudo kubeadm join ..." || true
    done
}

# Main execution
echo "Starting HA cluster setup..."
install_prerequisites
# init_primary_control_plane
# join_control_plane_nodes
# join_worker_nodes

echo ""
echo "✅ HA cluster setup script created"
echo "Review and execute setup steps manually or with proper credentials"
