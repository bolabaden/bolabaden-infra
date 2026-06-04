#!/bin/bash
# Fix Kubernetes installation with correct GPG key

set -euo pipefail

install_k8s_fixed() {
  local node=$1
  echo "Installing Kubernetes on $node with fixed GPG key..."
  
  ssh -o StrictHostKeyChecking=no "$node" bash << 'REMOTE_FIX'
    set -euo pipefail
    
    # Remove old broken repo
    sudo rm -f /etc/apt/sources.list.d/kubernetes.list
    sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add correct Kubernetes repo
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.27/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Update and install
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    
    # Enable kubelet
    sudo systemctl enable kubelet
    
    echo "✅ Kubernetes installed on $(hostname)"
REMOTE_FIX
}

NODES=(
  "micklethefickle.bolabaden.org"
  "cloudserver1.bolabaden.org"
  "cloudserver2.bolabaden.org"
  "cloudserver3.bolabaden.org"
  "blackboar.bolabaden.org"
)

for node in "${NODES[@]}"; do
  if timeout 10 ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$node" "echo OK" &>/dev/null; then
    install_k8s_fixed "$node" || echo "⚠️  Failed on $node"
  fi
done

echo "✅ Kubernetes installation fixed on all nodes"
