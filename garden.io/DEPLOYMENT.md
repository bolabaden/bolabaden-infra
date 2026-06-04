# Garden.io Deployment Guide

## Prerequisites

### 1. Install Garden CLI

```bash
# Option 1: Using the install script
curl -sL https://get.garden.io/install.sh | bash

# Option 2: Manual installation
GARDEN_VERSION="0.14.13"
mkdir -p /tmp/garden-install
curl -L "https://download.garden.io/core/${GARDEN_VERSION}/garden-${GARDEN_VERSION}-linux-amd64.tar.gz" | tar -xz -C /tmp/garden-install
export PATH="/tmp/garden-install:$PATH"

# Verify installation
garden version
```

### 2. Set Up Kubernetes Cluster (for k8s and ha-k8s environments)

**For local Kubernetes (k8s environment):**

```bash
# Option 1: Using Kind (Kubernetes in Docker)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name my-media-stack

# Verify
kubectl cluster-info --context kind-my-media-stack
```

**For HA Kubernetes (ha-k8s environment):**
- Ensure you have access to your HA Kubernetes cluster
- Configure kubeconfig: `export KUBECONFIG=~/.kube/ha-cluster-config`

### 3. Set Up Environment Variables

The project requires environment variables. Create a `.env` file or export them:

```bash
# Required for k8s environment
export SUDO_PASSWORD="your-sudo-password"
export MAIN_USERNAME="your-username"

# Cloudflare (if using)
export CLOUDFLARE_API_TOKEN="your-token"
export ACME_RESOLVER_EMAIL="your-email@example.com"
export CLOUDFLARE_EMAIL="your-email@example.com"
export CLOUDFLARE_API_KEY="your-api-key"
export CLOUDFLARE_ZONE_ID="your-zone-id"

# Add other required variables from project.garden.yml
# See the k8s environment section for full list
```

## Deployment Options

### Option 1: Deploy to Local Docker (default environment)

```bash
cd /home/ubuntu/my-media-stack/garden.io

# Validate configuration
garden validate --env default

# Deploy all services
garden deploy --env default

# Deploy specific services
garden deploy --env default redis traefik

# View status
garden status --env default

# View logs
garden logs --env default redis
```

### Option 2: Deploy to Local Kubernetes (k8s environment)

```bash
cd /home/ubuntu/my-media-stack/garden.io

# Ensure Kubernetes cluster is running
kubectl cluster-info --context kind-my-media-stack

# Validate configuration
garden validate --env k8s

# Deploy all services
garden deploy --env k8s

# Deploy with force (recreate resources)
garden deploy --env k8s --force

# View status
garden status --env k8s

# View logs
garden logs --env k8s redis
```

**Using the deployment script:**
```bash
cd /home/ubuntu/my-media-stack
chmod +x garden.io/deploy-to-k8s.sh
./garden.io/deploy-to-k8s.sh
```

### Option 3: Deploy to HA Kubernetes (ha-k8s environment)

```bash
cd /home/ubuntu/my-media-stack/garden.io

# Ensure HA cluster access
export KUBECONFIG=~/.kube/ha-cluster-config
kubectl cluster-info --context ha-cluster

# Validate configuration
garden validate --env ha-k8s

# Deploy all services
garden deploy --env ha-k8s

# View status
garden status --env ha-k8s
```

## Common Deployment Commands

### Validate Configuration
```bash
# Validate all environments
garden validate

# Validate specific environment
garden validate --env k8s
```

### Deploy Services
```bash
# Deploy all services
garden deploy --env k8s

# Deploy specific services
garden deploy --env k8s redis traefik litellm

# Deploy with force (recreate resources)
garden deploy --env k8s --force

# Deploy with sync mode (for development)
garden deploy --env k8s --sync
```

### Check Status
```bash
# View all services status
garden status --env k8s

# View specific service status
garden status --env k8s redis

# View with details
garden status --env k8s --output json
```

### View Logs
```bash
# View logs for a service
garden logs --env k8s redis

# Follow logs (stream)
garden logs --env k8s redis --follow

# View logs for multiple services
garden logs --env k8s redis traefik
```

### Execute Commands
```bash
# Execute command in a service container
garden exec --env k8s redis -- redis-cli ping

# Open interactive shell
garden exec --env k8s redis -- /bin/sh
```

### Clean Up
```bash
# Delete all services
garden delete --env k8s

# Delete specific services
garden delete --env k8s redis traefik
```

## Verification

### Check Kubernetes Resources
```bash
# View all pods
kubectl get pods --all-namespaces

# View deployments
kubectl get deployments --all-namespaces

# View services
kubectl get services --all-namespaces

# View ingress
kubectl get ingress --all-namespaces

# View specific namespace
kubectl get all -n my-media-stack-default
```

### Check Service Health
```bash
# Check pod status
kubectl get pods -n my-media-stack-default

# Describe a pod
kubectl describe pod <pod-name> -n my-media-stack-default

# View pod logs
kubectl logs <pod-name> -n my-media-stack-default

# View logs with follow
kubectl logs -f <pod-name> -n my-media-stack-default
```

## Troubleshooting

### Common Issues

1. **Garden CLI not found**
   ```bash
   export PATH="/tmp/garden-install:$PATH"
   # or
   export PATH="/root/.garden/bin:$PATH"
   ```

2. **Kubernetes cluster not accessible**
   ```bash
   # Check kubectl context
   kubectl config current-context
   
   # List available contexts
   kubectl config get-contexts
   
   # Switch context
   kubectl config use-context kind-my-media-stack
   ```

3. **Configuration validation fails**
   ```bash
   # Check for syntax errors
   garden validate --env k8s
   
   # Check specific file
   garden validate --env k8s --include redis
   ```

4. **Services not starting**
   ```bash
   # Check pod events
   kubectl describe pod <pod-name> -n my-media-stack-default
   
   # Check pod logs
   kubectl logs <pod-name> -n my-media-stack-default
   
   # Check resource limits
   kubectl top pods -n my-media-stack-default
   ```

5. **Volume mount issues**
   ```bash
   # Verify hostPath exists
   ls -la /path/to/volume
   
   # Check volume mounts
   kubectl describe pod <pod-name> -n my-media-stack-default | grep -A 10 "Mounts:"
   ```

## Environment-Specific Notes

### Default Environment (local-docker)
- Uses Docker directly (no Kubernetes)
- Faster for local development
- Limited to single-node deployment

### K8s Environment (local-kubernetes)
- Uses local Kubernetes cluster (Kind)
- Full Kubernetes features
- Good for testing Kubernetes deployments
- Namespace: `my-media-stack-default`

### HA-K8s Environment (ha-kubernetes)
- Uses high-availability Kubernetes cluster
- Production-ready
- Requires external cluster access
- Namespace: `my-media-stack-ha`

## Next Steps

After deployment:
1. Verify all services are running: `garden status --env k8s`
2. Check ingress routes: `kubectl get ingress --all-namespaces`
3. Test service endpoints
4. Monitor logs: `garden logs --env k8s --follow`
