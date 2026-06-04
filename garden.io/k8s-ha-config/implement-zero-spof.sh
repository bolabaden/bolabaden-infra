#!/bin/bash
set -euo pipefail

# Master script to implement zero SPOF across entire k3s cluster
# This script orchestrates all HA configurations

PRIMARY_NODE="${1:-micklethefickle.bolabaden.org}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Zero SPOF Implementation for k3s Cluster"
echo "=========================================="
echo ""

# Step 1: Verify Tailscale connectivity
echo "=== Step 1: Verifying Tailscale Connectivity ==="
PRIMARY_TS_IP=$(ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" "tailscale ip -4" 2>&1)
if [ -z "$PRIMARY_TS_IP" ]; then
    echo "ERROR: Primary node not connected to Tailscale"
    exit 1
fi
echo "✓ Primary node Tailscale IP: $PRIMARY_TS_IP"
echo ""

# Step 2: Wait for k3s to be ready
echo "=== Step 2: Waiting for k3s API to be ready ==="
ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for i in {1..60}; do
    if kubectl get nodes &>/dev/null; then
        echo "✓ k3s API is ready"
        break
    fi
    echo "Waiting for k3s API... (\$i/60)"
    sleep 5
done
EOF
echo ""

# Step 3: Configure Longhorn for HA
echo "=== Step 3: Configuring Longhorn for HA ==="
ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
bash "$SCRIPT_DIR/configure-longhorn-ha.sh"
EOF
echo ""

# Step 4: Scale all services for HA
echo "=== Step 4: Scaling All Services for HA ==="
ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
bash "$SCRIPT_DIR/scale-all-services-ha.sh"
EOF
echo ""

# Step 5: Deploy HA Ingress Controller
echo "=== Step 5: Deploying HA Ingress Controller ==="
ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Deploy NGINX Ingress Controller with HA
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Scale to 3 replicas with anti-affinity
kubectl scale deployment ingress-nginx-controller -n ingress-nginx --replicas=3

kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{
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
                      "key": "app.kubernetes.io/component",
                      "operator": "In",
                      "values": ["controller"]
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

kubectl apply -f - <<PDB
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ingress-nginx-controller-pdb
  namespace: ingress-nginx
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/component: controller
PDB
EOF
echo ""

# Step 6: Summary
echo "=== Implementation Summary ==="
ssh -o StrictHostKeyChecking=no "$PRIMARY_NODE" <<EOF
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Nodes:"
kubectl get nodes -o wide
echo ""

echo "System Deployments:"
kubectl get deployments -n kube-system -o wide
echo ""

echo "Longhorn Status:"
kubectl get pods -n longhorn-system -o wide | head -10
echo ""

echo "Ingress Controller:"
kubectl get pods -n ingress-nginx -o wide
echo ""

echo "Pod Distribution:"
kubectl get pods -A -o wide --no-headers | awk '{print \$8}' | sort | uniq -c | sort -rn
EOF

echo ""
echo "=========================================="
echo "Zero SPOF Implementation Complete"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Connect all worker nodes to Tailscale"
echo "2. Run setup-ha-control-plane.sh to add HA server nodes"
echo "3. Verify all services have 3+ replicas"
echo "4. Test failover scenarios"

