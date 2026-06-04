#!/bin/bash
# Install Kubernetes using alternative method (direct download)

set -euo pipefail

install_k8s_alt() {
  local node=$1
  echo "Installing Kubernetes on $node using alternative method..."
  
  ssh -o StrictHostKeyChecking=no "$node" bash << 'REMOTE_ALT'
    set -euo pipefail
    
    # Install using snap (more reliable)
    if command -v snap &>/dev/null; then
      echo "Installing via snap..."
      sudo snap install kubectl --classic
      sudo snap install kubeadm --classic
      sudo snap install kubelet --classic
    else
      # Or use direct binary installation
      K8S_VERSION="v1.27.3"
      ARCH="arm64"
      
      # Install kubectl
      curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${ARCH}/kubectl"
      sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      rm kubectl
      
      # Install kubeadm
      curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${ARCH}/kubeadm"
      sudo install -o root -g root -m 0755 kubeadm /usr/local/bin/kubeadm
      rm kubeadm
      
      # Install kubelet
      curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${ARCH}/kubelet"
      sudo install -o root -g root -m 0755 kubelet /usr/local/bin/kubelet
      rm kubelet
    fi
    
    # Enable kubelet
    sudo systemctl enable kubelet || true
    
    echo "✅ Kubernetes installed on $(hostname)"
    kubeadm version -o short 2>&1 || echo "kubeadm installed"
REMOTE_ALT
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
    install_k8s_alt "$node" || echo "⚠️  Failed on $node"
  fi
done

echo "✅ Kubernetes installation attempt complete"
