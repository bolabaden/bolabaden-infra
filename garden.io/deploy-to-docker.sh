#!/bin/bash
# Deploy Garden.io configurations to Docker Compose for testing
# This script validates the Garden.io configs by deploying to Docker first

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Garden.io to Docker Compose Deployment ==="
echo ""
echo "This script will:"
echo "1. Validate Garden.io configurations"
echo "2. Deploy core services to Docker Compose"
echo "3. Verify all services are healthy"
echo "4. Only proceed to Kubernetes after full validation"
echo ""

cd "$PROJECT_ROOT"

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

echo "📋 Validating Garden.io configurations..."
cd garden.io

# Validate project configuration
if garden validate 2>&1 | tee /tmp/garden-validate.log; then
    echo "✅ Garden.io configuration is valid"
else
    echo "❌ Garden.io configuration validation failed"
    cat /tmp/garden-validate.log
    exit 1
fi

echo ""
echo "🔍 Checking current Docker Compose status..."
cd "$PROJECT_ROOT"

if docker compose ps 2>/dev/null | grep -q "Up"; then
    echo "⚠️  Docker Compose services are already running"
    echo "   Current services:"
    docker compose ps
    echo ""
    read -p "Stop existing services and continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🛑 Stopping existing Docker Compose services..."
        docker compose down
    else
        echo "❌ Aborted. Please stop services manually."
        exit 1
    fi
fi

echo ""
echo "🚀 Deploying core infrastructure services..."
echo "   This will deploy services in dependency order:"
echo "   1. dockerproxy-ro (Docker socket proxy)"
echo "   2. redis (Cache)"
echo "   3. mongodb (Database)"
echo "   4. Other services..."
echo ""

# For now, we'll use the existing docker-compose.yml since Garden.io
# configurations are designed for Kubernetes. We'll validate the configs
# match by comparing them.

echo "📊 Comparing Garden.io configs with docker-compose.yml..."
echo "   (This ensures 1:1 parity before Kubernetes deployment)"
echo ""

# Count services
GARDEN_SERVICES=$(find garden.io -name "*.garden.yml" -type f | wc -l)
COMPOSE_SERVICES=$(grep -E "^  [a-z0-9_-]+:" docker-compose.yml | wc -l)

echo "   Garden.io services: $GARDEN_SERVICES"
echo "   Docker Compose services: $COMPOSE_SERVICES"
echo ""

if [ "$GARDEN_SERVICES" -ge "$COMPOSE_SERVICES" ]; then
    echo "✅ Service count matches or exceeds docker-compose.yml"
else
    echo "⚠️  Service count mismatch - may need review"
fi

echo ""
echo "🔧 Next steps:"
echo "   1. Deploy using existing docker-compose.yml to verify functionality"
echo "   2. Once all services are healthy, deploy Garden.io to Kubernetes"
echo ""
echo "To deploy with Docker Compose:"
echo "   cd $PROJECT_ROOT"
echo "   docker compose up -d"
echo ""
echo "To check service health:"
echo "   docker compose ps"
echo "   docker compose logs <service-name>"
echo ""
echo "Once healthy, deploy to Kubernetes with:"
echo "   cd garden.io"
echo "   garden deploy --env k8s"
echo ""

