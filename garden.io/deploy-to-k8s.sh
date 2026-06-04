#!/bin/bash
# Deploy Garden.io configurations to Kubernetes
# This script validates and deploys all services to Kubernetes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Garden.io to Kubernetes Deployment ==="
echo ""

cd "$PROJECT_ROOT/garden.io"

# Check if Garden CLI is available
if ! command -v garden &> /dev/null; then
    echo "⚠️  Garden CLI not found. Installing..."
    GARDEN_VERSION="0.14.13"
    GARDEN_URL="https://download.garden.io/core/${GARDEN_VERSION}/garden-${GARDEN_VERSION}-linux-amd64.tar.gz"
    
    mkdir -p /tmp/garden-install
    curl -L "$GARDEN_URL" | tar -xz -C /tmp/garden-install
    export PATH="/tmp/garden-install:$PATH"
    
    if ! command -v garden &> /dev/null; then
        echo "❌ Failed to install Garden CLI"
        exit 1
    fi
    echo "✅ Garden CLI installed"
fi

# Check Kubernetes access
echo "🔍 Checking Kubernetes cluster access..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot access Kubernetes cluster"
    echo "   Please ensure kubectl is configured correctly"
    exit 1
fi
echo "✅ Kubernetes cluster accessible"

# Validate configuration
echo ""
echo "📋 Validating Garden.io configurations..."
if garden validate --env k8s 2>&1 | tee /tmp/garden-validate-k8s.log; then
    echo "✅ Garden.io configuration is valid"
else
    echo "❌ Garden.io configuration validation failed"
    cat /tmp/garden-validate-k8s.log
    exit 1
fi

# Deploy to Kubernetes
echo ""
echo "🚀 Deploying to Kubernetes..."
echo "   This will deploy all services in dependency order"
echo ""

garden deploy --env k8s --force 2>&1 | tee /tmp/garden-deploy-k8s.log

DEPLOY_EXIT=$?

if [ $DEPLOY_EXIT -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "🔍 Verifying service health..."
    kubectl get pods -A | grep -E "NAME|Running|Pending" | head -20
    
    echo ""
    echo "📊 Service Status:"
    kubectl get deployments -A | grep -v "kube-system" | head -20
    
    echo ""
    echo "✅ Kubernetes deployment complete!"
else
    echo ""
    echo "❌ Deployment failed. Check logs above."
    exit 1
fi
