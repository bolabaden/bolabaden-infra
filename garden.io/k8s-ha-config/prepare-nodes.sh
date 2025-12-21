#!/bin/bash
# Prepare all nodes for Kubernetes HA cluster

set -euo pipefail

NODES=(
  "micklethefickle.bolabaden.org"
  "cloudserver1.bolabaden.org"
  "cloudserver2.bolabaden.org"
  "cloudserver3.bolabaden.org"
  "blackboar.bolabaden.org"
)

prepare_node() {
  local node=$1
  echo "=== Preparing ${node} ==="
  
  ssh -o StrictHostKeyChecking=no "${node}" bash << 'REMOTE_SCRIPT'
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
    
    echo "Detected OS: $OS $VER"
    
    # Install required packages
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
      sudo apt-get update
      sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        net-tools \
        iproute2
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
      sudo yum install -y \
        yum-utils \
        device-mapper-persistent-data \
        lvm2 \
        curl
    fi
    
    # Configure kernel parameters
    cat << 'KERNEL_PARAMS' | sudo tee -a /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
KERNEL_PARAMS
    
    sudo sysctl --system
    
    # Disable swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Load required kernel modules
    cat << 'MODULES' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
MODULES
    
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    echo "✅ ${node} prepared"
REMOTE_SCRIPT
}

for node in "${NODES[@]}"; do
  if timeout 10 ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${node}" "echo 'OK'" &>/dev/null; then
    prepare_node "${node}" || echo "⚠️  Failed to prepare ${node}"
  else
    echo "⚠️  Cannot access ${node}, skipping"
  fi
done

echo "✅ Node preparation complete"
