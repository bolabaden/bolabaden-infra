#!/bin/bash
# deployment.sh - Deploy the media server setup to a k3s cluster

set -e

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/k8s-manifests/generated"
DAGGER_FILE="${SCRIPT_DIR}/src/dagger_app/bolabaden/dagger_compose.py"

# Configuration
DOMAIN="bolabaden.com"      # Replace with your domain
EMAIL="bolabaden@gmail.com" # Replace with your email
ROOT_DIR="/mnt/media-data"  # Replace with your media storage location

# Step 1: Install required packages
echo "=== Installing required packages ==="
apt-get update
apt-get install -y python3 python3-pip python3-yaml kubectl curl

# Step 2: Create directories for storage
echo "=== Creating storage directories ==="
mkdir -p /mnt/media-data/{configs,data}
mkdir -p /mnt/media-data/data/{media,downloads}
mkdir -p /mnt/media-data/data/media/{movies,tv,music,books,comics}
chmod -R 777 /mnt/media-data # Ensure permissions are set

# Step 3: Create k3s cluster using the installation script
echo "=== Setting up k3s cluster ==="
if [ ! -f "/usr/local/bin/k3s" ]; then
    bash "${SCRIPT_DIR}/k3s-install.sh"
else
    echo "k3s is already installed, skipping installation"
fi

# Step 4: Wait for k3s to be ready
echo "=== Waiting for k3s to be ready ==="
kubectl wait --for=condition=available --timeout=300s deployment/traefik -n kube-system || echo "Traefik not yet deployed, continuing anyway"

# Step 5: Configure environment variables
echo "=== Configuring environment variables ==="
export DOMAIN="$DOMAIN"
export ROOT_DIR="$ROOT_DIR"

# Create ConfigMap with environment variables
cat <<EOF >"${SCRIPT_DIR}/k8s-manifests/env-configmap.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: media-server-config
data:
  DOMAIN: "$DOMAIN"
  ROOT_DIR: "$ROOT_DIR"
  TZ: "America/Chicago"
  PUID: "1002"
  PGID: "988"
EOF

# Step 6: Install cert-manager for HTTPS certificates
echo "=== Installing cert-manager ==="
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
sleep 60 # Wait for cert-manager to be ready

# Update email in ClusterIssuer
sed -i "s/your-email@domain.com/$EMAIL/g" "${SCRIPT_DIR}/k8s-manifests/cert-manager.yaml"

# Step 7: Apply storage configuration
echo "=== Applying storage configuration ==="
kubectl apply -f "${SCRIPT_DIR}/k8s-manifests/storage.yaml"

# Step 8: Apply cert-manager configuration
echo "=== Applying cert-manager configuration ==="
kubectl apply -f "${SCRIPT_DIR}/k8s-manifests/cert-manager.yaml"

# Step 9: Apply network policies
echo "=== Applying network policies ==="
kubectl apply -f "${SCRIPT_DIR}/k8s-manifests/network-policy.yaml"

# Step 10: Apply ConfigMap with environment variables
echo "=== Applying environment variables ConfigMap ==="
kubectl apply -f "${SCRIPT_DIR}/k8s-manifests/env-configmap.yaml"

# Step 11: Generate Kubernetes manifests from Dagger container definitions
echo "=== Generating Kubernetes manifests from Dagger container definitions ==="
mkdir -p "$OUTPUT_DIR"
python3 "${SCRIPT_DIR}/convert_to_k8s.py" "$DAGGER_FILE" "$OUTPUT_DIR"

# Step 12: Apply generated Kubernetes manifests
echo "=== Applying generated Kubernetes manifests ==="
kubectl apply -f "$OUTPUT_DIR"

# Step 13: Setup automatic horizontal pod autoscaling
echo "=== Setting up Horizontal Pod Autoscaler ==="
cat <<EOF >"${SCRIPT_DIR}/k8s-manifests/hpa.yaml"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: media-services-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: jellyfin  # Example - can be changed to any key service
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 60
EOF

kubectl apply -f "${SCRIPT_DIR}/k8s-manifests/hpa.yaml"

# Step 14: Verify deployment
echo "=== Verifying deployment ==="
kubectl get nodes
kubectl get pods
kubectl get services
kubectl get ingress

echo "=== Deployment completed successfully ==="
echo "Your media server is now running on k3s in high availability mode!"
echo "Access your services at: https://<service-name>.$DOMAIN"
