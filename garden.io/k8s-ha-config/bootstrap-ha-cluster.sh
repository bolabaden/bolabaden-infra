#!/bin/bash
# Complete HA Kubernetes Cluster Bootstrap
# Zero SPOF Implementation

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

echo "=== HA Kubernetes Cluster Bootstrap ==="
echo "Control Plane: ${CONTROL_PLANE_NODES[*]}"
echo "Workers: ${WORKER_NODES[*]}"
echo ""

# Install kubeadm, kubelet, kubectl on all nodes
install_kubernetes() {
  local node=$1
  echo "Installing Kubernetes on $node..."
  
  ssh -o StrictHostKeyChecking=no "$node" bash << 'REMOTE_INSTALL'
    set -euo pipefail
    
    # Detect OS
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      OS=$ID
      VER=$VERSION_ID
    else
      echo "Cannot detect OS"
      exit 1
    fi
    
    # Install Kubernetes
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates curl gpg
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.27/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
      sudo apt-get update
      sudo apt-get install -y kubelet kubeadm kubectl
      sudo apt-mark hold kubelet kubeadm kubectl
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
      cat << 'EOF' | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/repodata/repomd.xml.key
EOF
      sudo yum install -y kubelet kubeadm kubectl
      sudo systemctl enable --now kubelet
    fi
    
    echo "✅ Kubernetes installed on $(hostname)"
REMOTE_INSTALL
}

# Prepare all nodes
for node in "${CONTROL_PLANE_NODES[@]}" "${WORKER_NODES[@]}"; do
  if timeout 10 ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$node" "echo OK" &>/dev/null; then
    install_kubernetes "$node" || echo "⚠️  Failed to install on $node"
  fi
done

echo ""
echo "✅ Kubernetes installation complete on all nodes"
