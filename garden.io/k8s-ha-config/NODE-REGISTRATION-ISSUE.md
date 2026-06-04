# Node Registration Issue - Troubleshooting

## Problem
The primary node (micklethefickle.bolabaden.org) is not registering itself in the k3s cluster.

## Root Causes Identified

### 1. Old Kubernetes Processes
- Old `kubelet` and `kube-apiserver` processes from previous kubeadm installation were running
- These were using the same containerd socket and port 6443
- **Fix**: Stopped old processes with `pkill`

### 2. Containerd Not Ready
- k3s logs show: `Waiting for containerd startup: rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService`
- **Fix**: Restarted containerd service

### 3. File Descriptor Limits
- Error: `too many open files`
- **Fix**: Increased limits to 65536 in `/etc/security/limits.conf` and systemd override

### 4. etcd IP Mismatch
- etcd initialized with old IP but k3s configured for Tailscale IP
- **Fix**: Reset etcd and reinitialized

## Current Status
- k3s API server is running and responding to health checks
- Node registration still pending
- System pods are in Pending state (waiting for node)

## Next Steps
1. Verify k3s is fully started after stopping old processes
2. Check if node registers automatically once k3s stabilizes
3. If not, investigate kubelet component within k3s
4. Consider manual node creation if automatic registration fails

## Commands to Check Status
```bash
# Check k3s status
sudo systemctl status k3s

# Check for nodes
kubectl get nodes -o wide

# Check k3s logs
sudo journalctl -u k3s -n 50 --no-pager

# Check if old processes are gone
ps aux | grep -E '(kubelet|kube-apiserver)' | grep -v grep
```

