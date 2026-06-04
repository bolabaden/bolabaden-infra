#!/bin/bash
set -euo pipefail

# Script to scale all system services to HA (3+ replicas with anti-affinity)

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

echo "=== Scaling All Services for HA ==="

# CoreDNS - Scale to 3 replicas with anti-affinity
echo "=== Configuring CoreDNS HA ==="
kubectl scale deployment coredns -n kube-system --replicas=3

kubectl patch deployment coredns -n kube-system -p '{
  "spec": {
    "template": {
      "spec": {
        "affinity": {
          "podAntiAffinity": {
            "requiredDuringSchedulingIgnoredDuringExecution": [
              {
                "labelSelector": {
                  "matchExpressions": [
                    {
                      "key": "k8s-app",
                      "operator": "In",
                      "values": ["kube-dns"]
                    }
                  ]
                },
                "topologyKey": "kubernetes.io/hostname"
              }
            ]
          }
        }
      }
    }
  }
}'

kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: coredns-pdb
  namespace: kube-system
spec:
  minAvailable: 2
  selector:
    matchLabels:
      k8s-app: kube-dns
EOF

# Metrics Server - Scale to 3 replicas
echo "=== Configuring Metrics Server HA ==="
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    kubectl scale deployment metrics-server -n kube-system --replicas=3
    
    kubectl patch deployment metrics-server -n kube-system -p '{
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
                            "key": "k8s-app",
                            "operator": "In",
                            "values": ["metrics-server"]
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
fi

# Local Path Provisioner - Scale to 3 replicas (or remove if using Longhorn)
echo "=== Configuring Local Path Provisioner ==="
if kubectl get deployment local-path-provisioner -n kube-system &>/dev/null; then
    kubectl scale deployment local-path-provisioner -n kube-system --replicas=3
fi

echo "=== Service HA Configuration Complete ==="
kubectl get deployments -n kube-system -o wide

