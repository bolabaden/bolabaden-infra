#!/bin/bash
# k3s-install.sh - Script to install and configure a high-availability k3s cluster

set -e

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

# Configuration variables
MASTER_NODES=("server1" "server2" "server3")  # First 3 servers will be master nodes
WORKER_NODES=("server4" "server5")            # Remaining 2 servers will be worker nodes
VIP="192.168.1.100"                           # Virtual IP for the k3s API server
K3S_VERSION="v1.27.7+k3s1"                    # K3s version
API_SERVER_PORT="6443"
TOKEN=$(openssl rand -hex 32)                 # Generate a random token for node joining
INSTALL_K3S_EXEC=""

# Create token file for node joining
echo "$TOKEN" > /var/lib/rancher/k3s/server/node-token

echo "=== Setting up k3s high availability cluster ==="
echo "Master nodes: ${MASTER_NODES[*]}"
echo "Worker nodes: ${WORKER_NODES[*]}"
echo "VIP address: $VIP"

# Function to install k3s on a master node
install_master() {
    local node=$1
    local node_index=$2
    
    echo "Setting up master node: $node"
    
    if [ "$node_index" -eq 0 ]; then
        # First master is the initializing server
        INSTALL_K3S_EXEC="server --cluster-init --tls-san $VIP --node-external-ip $VIP"
    else
        # Other masters join the cluster
        INSTALL_K3S_EXEC="server --server https://${MASTER_NODES[0]}:$API_SERVER_PORT --token $TOKEN --tls-san $VIP"
    fi
    
    ssh "$node" "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=$TOKEN sh -s - $INSTALL_K3S_EXEC"
    
    # Wait for the node to be ready
    echo "Waiting for master node $node to be ready..."
    sleep 30
}

# Function to install k3s on a worker node
install_worker() {
    local node=$1
    
    echo "Setting up worker node: $node"
    
    # Workers connect to the VIP
    ssh "$node" "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_URL=https://$VIP:$API_SERVER_PORT K3S_TOKEN=$TOKEN sh -"
    
    # Wait for the node to be ready
    echo "Waiting for worker node $node to be ready..."
    sleep 20
}

# Setup master nodes (first 3 servers)
for i in "${!MASTER_NODES[@]}"; do
    install_master "${MASTER_NODES[$i]}" "$i"
done

# Setup worker nodes (remaining 2 servers)
for node in "${WORKER_NODES[@]}"; do
    install_worker "$node"
done

# Copy kubeconfig to local machine for kubectl access
mkdir -p ~/.kube
scp "${MASTER_NODES[0]}:/etc/rancher/k3s/k3s.yaml" ~/.kube/config
sed -i "s/127.0.0.1/$VIP/g" ~/.kube/config

echo "=== Kubernetes cluster setup complete ==="
echo "You can now use kubectl to interact with your cluster"
echo "Run 'kubectl get nodes' to verify the cluster status"

# Setup kube-vip for high availability
echo "Setting up kube-vip for HA..."
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-vip
  namespace: kube-system
data:
  config.yaml: |
    vip_interface: eth0
    vip_address: $VIP
    vip_leaderelection: true
    enable_load_balancer: true
EOF

echo "=== High-availability setup complete ==="
echo "Your k3s cluster is now running in HA mode with a virtual IP: $VIP" 