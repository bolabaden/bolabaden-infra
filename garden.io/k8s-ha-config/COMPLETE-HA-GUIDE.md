# Complete High Availability Kubernetes Implementation Guide

## Overview
This guide provides step-by-step instructions for setting up a zero-SPOF Kubernetes cluster across 5 nodes.

## Prerequisites
- SSH access to all 5 nodes
- Root or sudo access on all nodes
- Network connectivity between all nodes
- Minimum 2GB RAM and 2 CPU cores per node

## Implementation Steps

### Phase 1: Node Preparation
1. Run node preparation script:
   ```bash
   ./garden.io/k8s-ha-config/prepare-nodes.sh
   ```

2. Verify all nodes are prepared:
   ```bash
   for node in micklethefickle.bolabaden.org cloudserver1.bolabaden.org cloudserver2.bolabaden.org cloudserver3.bolabaden.org blackboar.bolabaden.org; do
     ssh $node "uname -a && cat /etc/os-release"
   done
   ```

### Phase 2: etcd Cluster Setup
1. Install etcd on control plane nodes
2. Configure 3-node etcd cluster
3. Enable TLS for etcd communication
4. Test etcd cluster health

### Phase 3: Control Plane HA
1. Install kubeadm, kubelet, kubectl on control plane nodes
2. Initialize first control plane node
3. Join additional control plane nodes
4. Set up load balancer for kube-apiserver
5. Verify control plane HA

### Phase 4: Worker Node Joining
1. Install kubeadm, kubelet on worker nodes
2. Join worker nodes to cluster
3. Verify node registration

### Phase 5: CNI Installation
1. Install Calico CNI plugin
2. Configure BGP peering
3. Verify pod networking

### Phase 6: Storage Setup
1. Install Longhorn distributed storage
2. Configure replication factor 3
3. Set up storage classes
4. Test volume provisioning

### Phase 7: Core Services HA
1. Scale CoreDNS to 3 replicas
2. Configure anti-affinity
3. Deploy ingress controller with HA
4. Verify service availability

### Phase 8: Application Deployment
1. Deploy all services with Garden.io
2. Configure pod disruption budgets
3. Set up anti-affinity rules
4. Verify all services are running

### Phase 9: Failover Testing
1. Test control plane node failure
2. Test worker node failure
3. Test storage node failure
4. Verify zero data loss

## Verification Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check etcd cluster
kubectl get pods -n kube-system | grep etcd

# Check storage
kubectl get storageclass
kubectl get pv

# Check service availability
kubectl get svc --all-namespaces

# Test failover
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## Success Criteria
- ✅ All 5 nodes are part of the cluster
- ✅ etcd cluster has 3 healthy nodes
- ✅ Control plane has 3 nodes
- ✅ All services have multiple replicas
- ✅ Storage replication is working
- ✅ Services survive single node failure
- ✅ Zero data loss in failover scenarios
