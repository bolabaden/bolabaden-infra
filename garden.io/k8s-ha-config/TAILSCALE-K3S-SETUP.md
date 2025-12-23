# Tailscale + k3s Integration Guide

## Overview

This document describes the canonical/idiomatic setup for using Tailscale with k3s for Kubernetes networking. This approach uses Tailscale's mesh VPN to provide secure, encrypted connectivity between all k3s nodes.

## Current Status

### Primary Node (micklethefickle.bolabaden.org)
- ✅ Tailscale connected: `100.98.182.207`
- ✅ k3s configured to use Tailscale IP
- ✅ API server accessible via Tailscale IP
- ✅ DNS override disabled (`--accept-dns=false`)

### Worker Nodes
- ⚠️ **blackboar.bolabaden.org** - Needs Tailscale connection
- ⚠️ **cloudserver1.bolabaden.org** - Needs Tailscale connection  
- ⚠️ **cloudserver2.bolabaden.org** - Needs Tailscale connection

## Configuration Applied

### Primary Node Configuration

```yaml
# /etc/rancher/k3s/config.yaml
bind-address: 0.0.0.0
advertise-address: 100.98.182.207  # Tailscale IP
node-ip: 100.98.182.207            # Tailscale IP
node-external-ip: 100.98.182.207   # Tailscale IP
service-cidr: 10.43.0.0/16
cluster-cidr: 10.42.0.0/16
flannel-iface: tailscale0           # Use Tailscale interface
```

### Tailscale DNS Configuration

**Critical**: Tailscale DNS override is disabled to prevent conflicts with Kubernetes CoreDNS:

```bash
tailscale set --accept-dns=false
```

This ensures:
- Tailscale MagicDNS still works for `.myscale.bolabaden.org` names
- Kubernetes CoreDNS handles cluster DNS (`.svc.cluster.local`, etc.)
- No DNS conflicts or overrides

## Setup Steps for Each Node

### 1. Connect Node to Tailscale

For nodes using Headscale (self-hosted Tailscale):

```bash
sudo tailscale up --reset \
  --accept-dns=false \
  --accept-routes \
  --login-server=https://headscale-server.bolabaden.org
```

**Note**: Nodes need to be authenticated through the Headscale admin interface or using an auth key.

### 2. Get Tailscale IP

```bash
TAILSCALE_IP=$(tailscale ip -4)
echo "Tailscale IP: $TAILSCALE_IP"
```

### 3. Configure k3s for Tailscale

#### For Server Nodes:

```bash
sudo mkdir -p /etc/rancher/k3s
cat <<EOF | sudo tee /etc/rancher/k3s/config.yaml
bind-address: 0.0.0.0
advertise-address: ${TAILSCALE_IP}
node-ip: ${TAILSCALE_IP}
node-external-ip: ${TAILSCALE_IP}
service-cidr: 10.43.0.0/16
cluster-cidr: 10.42.0.0/16
flannel-iface: tailscale0
EOF
sudo systemctl restart k3s
```

#### For Agent Nodes:

```bash
sudo mkdir -p /etc/rancher/k3s
# Preserve existing server config, add Tailscale settings
cat <<EOF | sudo tee -a /etc/rancher/k3s/config.yaml
node-ip: ${TAILSCALE_IP}
node-external-ip: ${TAILSCALE_IP}
flannel-iface: tailscale0
EOF
sudo systemctl restart k3s-agent
```

### 4. Verify Configuration

```bash
# Check Tailscale status
tailscale status

# Check k3s node status
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes -o wide

# Test API server via Tailscale IP
curl -k https://${TAILSCALE_IP}:6443/healthz
```

## Benefits of This Approach

1. **Secure Mesh Networking**: All node-to-node communication is encrypted via Tailscale
2. **No Firewall Rules Needed**: Tailscale handles NAT traversal automatically
3. **Works Across Networks**: Nodes can be in different data centers/clouds
4. **DNS Compatibility**: Tailscale DNS and Kubernetes DNS coexist without conflicts
5. **Canonical Integration**: Uses k3s's built-in `flannel-iface` option for CNI integration

## Troubleshooting

### Node Cannot Connect to API Server

1. Verify Tailscale connectivity:
   ```bash
   ping <tailscale-ip-of-primary>
   ```

2. Check k3s is listening on Tailscale interface:
   ```bash
   sudo netstat -tlnp | grep 6443
   ```

3. Verify firewall rules (if any):
   ```bash
   sudo iptables -L -n | grep 6443
   ```

### DNS Issues

1. Ensure Tailscale DNS override is disabled:
   ```bash
   tailscale set --accept-dns=false
   ```

2. Check CoreDNS is running:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   ```

### Flannel Not Working

1. Verify Tailscale interface exists:
   ```bash
   ip addr show tailscale0
   ```

2. Check Flannel is using Tailscale interface:
   ```bash
   kubectl get pods -n kube-flannel -o wide
   kubectl logs -n kube-flannel <flannel-pod> | grep interface
   ```

## Next Steps

1. **Authenticate Worker Nodes**: Connect blackboar, cloudserver1, and cloudserver2 to Tailscale
2. **Configure Worker Nodes**: Apply k3s Tailscale configuration to each worker
3. **Join Nodes to Cluster**: Update k3s-agent configs to use primary's Tailscale IP
4. **Verify Cluster**: Ensure all nodes can communicate via Tailscale
5. **Test Failover**: Verify HA functionality with Tailscale networking

## References

- [k3s Networking Documentation](https://docs.k3s.io/networking)
- [k3s Distributed/Multicloud with Tailscale](https://docs.k3s.io/networking/distributed-multicloud)
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator)
- [Tailscale DNS Configuration](https://tailscale.com/kb/1054/dns/)

