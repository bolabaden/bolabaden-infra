#!/bin/bash
set -euo pipefail

# Script to configure Longhorn for HA with replication factor 3

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

echo "=== Configuring Longhorn for HA ==="

# Check if Longhorn is installed
if ! kubectl get namespace longhorn-system &>/dev/null; then
    echo "Longhorn not found. Installing..."
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml
    echo "Waiting for Longhorn to be ready..."
    kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s
fi

echo "=== Setting Default Replication Factor to 3 ==="

# Update Longhorn settings for HA
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: longhorn-storageclass
  namespace: longhorn-system
data:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
EOF

echo "=== Updating Longhorn Manager for HA ==="

# Scale Longhorn Manager to 3+ replicas
kubectl scale deployment longhorn-manager -n longhorn-system --replicas=3

# Add anti-affinity to Longhorn Manager
kubectl patch deployment longhorn-manager -n longhorn-system -p '{
  "spec": {
    "template": {
      "spec": {
        "affinity": {
          "podAntiAffinity": {
            "preferredDuringSchedulingIgnoredDuringExecution": [
              {
                "weight": 100,
                "podAffinityTerm": {
                  "labelSelector": {
                    "matchExpressions": [
                      {
                        "key": "app",
                        "operator": "In",
                        "values": ["longhorn-manager"]
                      }
                    ]
                  },
                  "topologyKey": "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }
    }
  }
}'

echo "=== Creating PodDisruptionBudget for Longhorn ==="

kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: longhorn-manager-pdb
  namespace: longhorn-system
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: longhorn-manager
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: longhorn-ui-pdb
  namespace: longhorn-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: longhorn-ui
EOF

echo "=== Longhorn HA Configuration Complete ==="
echo "Replication factor: 3"
echo "Min available managers: 2"
kubectl get pods -n longhorn-system -o wide

