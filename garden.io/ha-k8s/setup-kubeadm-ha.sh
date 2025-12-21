#!/bin/bash
# Use kubeadm's built-in HA support (simpler than external etcd)

PRIMARY="micklethefickle.bolabaden.org"
CP_NODES=("cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
WORKERS=("cloudserver3.bolabaden.org" "blackboar.bolabaden.org")

echo "=== kubeadm HA Cluster Setup ==="
echo "Using kubeadm's built-in HA (stacked etcd)"
echo ""

# Create HA config
cat > /tmp/kubeadm-ha-stacked.yaml << 'KUBEADM_CONFIG'
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.27.3
controlPlaneEndpoint: "micklethefickle.bolabaden.org:6443"
etcd:
  local:
    dataDir: /var/lib/etcd
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
apiServer:
  certSANs:
    - "micklethefickle.bolabaden.org"
    - "cloudserver1.bolabaden.org"
    - "cloudserver2.bolabaden.org"
    - "cloudserver3.bolabaden.org"
    - "blackboar.bolabaden.org"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "0.0.0.0"
  bindPort: 6443
KUBEADM_CONFIG

# Copy to primary
scp /tmp/kubeadm-ha-stacked.yaml ubuntu@$PRIMARY:/tmp/kubeadm-config.yaml

# Initialize primary
echo "=== Initializing Primary ==="
ssh ubuntu@$PRIMARY "sudo kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs 2>&1 | tee /tmp/kubeadm-init.log"

# Get join commands
echo ""
echo "=== Getting Join Commands ==="
JOIN_CMD=$(ssh ubuntu@$PRIMARY "sudo kubeadm token create --print-join-command 2>/dev/null")
CERT_KEY=$(ssh ubuntu@$PRIMARY "sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1")

echo "Join command: $JOIN_CMD"
echo "Certificate key: $CERT_KEY"

# Join control plane nodes
for node in "${CP_NODES[@]}"; do
    echo "Joining $node to control plane..."
    ssh ubuntu@$node "sudo $JOIN_CMD --control-plane --certificate-key $CERT_KEY"
done

# Join workers
for node in "${WORKERS[@]}"; do
    echo "Joining $node as worker..."
    ssh ubuntu@$node "sudo $JOIN_CMD"
done

echo ""
echo "✅ HA cluster setup complete"
