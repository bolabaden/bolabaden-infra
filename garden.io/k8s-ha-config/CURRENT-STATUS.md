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
- ✅ **Flannel** - Running and healthy
- Status: `kube-flannel-ds` daemonset running on blackboar (1/1 Ready, 11 restarts but now stable)
- Fixed: Added explicit service-cidr (10.43.0.0/16) and cluster-cidr (10.42.0.0/16) to k3s config
- Network: Pod networking functional, service networking functional

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
   - Root cause: Network connectivity - cannot reach primary API server (10.16.1.78:6443)
   - Status: cloudserver1 has k3s-agent service but connection times out
   - Solution: Investigate firewall rules, network routing, or use service IP (10.43.0.1:443)

2. **CoreDNS**: Running but not ready
   - Root cause: Cannot watch Kubernetes API - "Failed to watch" errors
   - Status: Pod running but readiness probe failing (503)
   - Solution: CoreDNS needs to connect to API server - may be related to node connectivity issue

3. **Flannel**: Intermittent crashes
   - Status: Pod restarts frequently but sometimes runs successfully
   - Need to investigate root cause of crashes

4. **Kubelet Proxy**: 502 errors when accessing logs from worker nodes
   - Root cause: API server cannot proxy to worker node kubelets
   - Status: Primary can reach blackboar kubelet directly, but proxy fails
   - Impact: Cannot get pod logs via kubectl from worker nodes

5. **Other System Pods**: Several pods in CrashLoopBackOff
   - Traefik helm install jobs
   - Metrics server  
   - Local path provisioner
   - Longhorn UI

## Next Steps

1. Fix CoreDNS scaling
2. Verify and fix Longhorn storage
3. Configure HA for all services
4. Continue troubleshooting cloudserver1 and cloudserver2 node joining
5. Deploy all Garden.io services with HA configuration

