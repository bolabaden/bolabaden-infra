# Kubernetes HA Cluster - Current Status

## Node Status

### Working Nodes
- ✅ **micklethefickle.bolabaden.org** (Primary control plane) - Running k3s server
- ✅ **blackboar.bolabaden.org** (Worker) - Ready, k3s-agent running
- ⚠️ **cloudserver1.bolabaden.org** - k3s-agent service running, attempting to join cluster
- ⚠️ **cloudserver2.bolabaden.org** - k3s installation in progress

### Removed Nodes
- ❌ **cloudserver3.bolabaden.org** - Removed from cluster (unreachable)

## Current Cluster Components

### CNI (Networking)
- ⚠️ **Flannel** - Installed but pods in CrashLoopBackOff
- Status: `kube-flannel-ds` daemonset running on blackboar, but container crashing
- Issue: Need to investigate container logs

### DNS
- ⚠️ **CoreDNS** - Multiple pods, some pending, running pod not ready
- Issue: Readiness probe failing (503), duplicate deployments
- Action: Cleaning up pending pods and fixing deployment

### Storage
- ⚠️ **Longhorn** - Installed but status unknown
- Need to verify replication factor and node availability

### Control Plane
- ✅ **k3s embedded etcd** - Running on primary node (micklethefickle)
- ⚠️ **API Server** - Listening on IPv6 only (:::6443), bind-address config not taking effect
- ⚠️ **HA Control Plane** - cloudserver1 and cloudserver2 cannot connect (network/firewall issue)

## Issues to Resolve

1. **Node Joining**: cloudserver1 and cloudserver2 not joining cluster
   - Root cause: DNS resolution issues, service not starting properly
   - Solution: Use IP addresses instead of hostnames, manually create systemd service

2. **System Pods**: Several pods in CrashLoopBackOff
   - Traefik helm install jobs
   - Metrics server
   - Local path provisioner

3. **CoreDNS**: Too many replicas for available nodes
   - Solution: Scale to match available nodes (2 replicas)

## Next Steps

1. Fix CoreDNS scaling
2. Verify and fix Longhorn storage
3. Configure HA for all services
4. Continue troubleshooting cloudserver1 and cloudserver2 node joining
5. Deploy all Garden.io services with HA configuration

