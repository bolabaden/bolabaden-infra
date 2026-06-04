# High Availability Kubernetes Infrastructure

## Overview

This configuration provides a zero single-point-of-failure (SPOF) Kubernetes cluster with comprehensive failover capabilities.

## Cluster Topology

### Control Plane Nodes (HA)
- **Primary**: micklethefickle.bolabaden.org
- **Fallback 1**: cloudserver1.bolabaden.org
- **Fallback 2**: cloudserver2.bolabaden.org

### Worker Nodes
- cloudserver3.bolabaden.org
- blackboar.bolabaden.org

## HA Components

### 1. Control Plane HA
- **kube-apiserver**: Load balanced across 3 control plane nodes
- **etcd**: External cluster with 3 nodes, replication factor 3
- **kube-scheduler**: Multiple replicas with leader election
- **kube-controller-manager**: Multiple replicas with leader election

### 2. Storage HA
- **CSI Driver**: Rook/Ceph with 3x replication
- **Storage Classes**: HA-replicated storage class
- **Volume Replication**: Automatic across nodes
- **Data Loss Prevention**: Synchronous replication

### 3. Networking HA
- **CNI**: Calico with BGP for multi-node networking
- **Service Mesh**: Optional Istio/Linkerd for service-level HA
- **Load Balancing**: MetalLB or cloud LB for external access

### 4. DNS HA
- **CoreDNS**: Multiple replicas with anti-affinity
- **DNS Failover**: Automatic failover to healthy replicas

### 5. Ingress HA
- **Ingress Controller**: Multiple replicas across nodes
- **Ingress Failover**: Automatic traffic routing to healthy replicas

### 6. Application HA
- **Pod Anti-Affinity**: Ensures pods spread across nodes
- **Pod Disruption Budgets**: Maintains minimum available replicas
- **Health Checks**: Comprehensive liveness and readiness probes
- **Auto-scaling**: HPA for automatic scaling based on load

## Failover Scenarios

### Node Failure
- Automatic pod rescheduling to healthy nodes
- Storage volumes remain accessible via replication
- Services continue with remaining replicas

### Control Plane Failure
- Remaining control plane nodes take over
- etcd continues with quorum (2 of 3 nodes)
- API server load balanced across remaining nodes

### Storage Failure
- Automatic failover to replicated storage
- Zero data loss with synchronous replication
- Automatic recovery when storage is restored

### Network Partition
- Split-brain prevention via etcd quorum
- Services continue in majority partition
- Automatic reconciliation when partition heals

## Deployment

1. **Initialize Cluster:**
   ```bash
   ./setup-ha-cluster.sh
   ```

2. **Deploy Storage:**
   ```bash
   kubectl apply -f storage-ha.yaml
   kubectl apply -f stateful-storage-ha.yaml
   ```

3. **Deploy Services:**
   ```bash
   ./deploy-ha.sh
   ```

## Monitoring

- **Cluster Health**: kubectl get nodes, kubectl get pods
- **Storage Health**: kubectl get cephcluster -n rook-ceph
- **Service Health**: kubectl get endpoints, kubectl get services

## Testing Failover

1. **Node Failure Test:**
   ```bash
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   # Verify pods reschedule and services continue
   ```

2. **Storage Failure Test:**
   ```bash
   # Simulate storage node failure
   # Verify data remains accessible
   ```

3. **Control Plane Failure Test:**
   ```bash
   # Stop one control plane node
   # Verify cluster continues operating
   ```
