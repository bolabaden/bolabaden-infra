#!/bin/bash

# Deployment script for LLM Fallbacks system
# This script builds and deploys the updated Docker containers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} WARNING: $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ERROR: $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/compose"
LLM_FALLBACKS_DIR="$PROJECT_ROOT/src/llm_fallbacks"

# Check if we're in the right directory
if [ ! -f "$COMPOSE_DIR/docker-compose.llm.yml" ]; then
    error "docker-compose.llm.yml not found in $COMPOSE_DIR"
    exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose > /dev/null 2>&1; then
        error "Docker Compose is not installed. Please install it and try again."
        exit 1
    fi
    
    # Check if required environment variables are set
    if [ -z "$OPENROUTER_API_KEY" ]; then
        warn "OPENROUTER_API_KEY is not set. Model updates may fail."
    fi
    
    log "Prerequisites check completed."
}

# Function to build Docker images
build_images() {
    log "Building Docker images..."
    
    cd "$LLM_FALLBACKS_DIR"
    
    # Build model updater image
    log "Building model updater image..."
    docker build -f Dockerfile.model-updater -t llm-fallbacks:model-updater .
    
    # Build scheduler image
    log "Building scheduler image..."
    docker build -f Dockerfile.scheduler -t llm-fallbacks:scheduler .
    
    log "Docker images built successfully."
}

# Function to deploy services
deploy_services() {
    log "Deploying services..."
    
    cd "$COMPOSE_DIR"
    
    # Stop existing services
    log "Stopping existing services..."
    docker-compose -f docker-compose.llm.yml down
    
    # Start services
    log "Starting services..."
    docker-compose -f docker-compose.llm.yml up -d
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    docker-compose -f docker-compose.llm.yml ps
    
    log "Services deployed successfully."
}

# Function to test deployment
test_deployment() {
    log "Testing deployment..."
    
    cd "$COMPOSE_DIR"
    
    # Check if all services are running
    if docker-compose -f docker-compose.llm.yml ps | grep -q "Up"; then
        log "All services are running."
    else
        error "Some services failed to start."
        docker-compose -f docker-compose.llm.yml logs
        exit 1
    fi
    
    # Test model updater manually
    log "Testing model updater..."
    docker-compose -f docker-compose.llm.yml run --rm model-updater python -c "
import sys
sys.path.append('/app')
from llm_fallbacks.generate_configs import main
print('Model updater test completed successfully')
"
    
    log "Deployment test completed successfully."
}

# Function to show status
show_status() {
    log "Current deployment status:"
    cd "$COMPOSE_DIR"
    docker-compose -f docker-compose.llm.yml ps
}

# Function to show logs
show_logs() {
    log "Recent logs:"
    cd "$COMPOSE_DIR"
    docker-compose -f docker-compose.llm.yml logs --tail=50
}

# Function to force model update
force_update() {
    log "Forcing model update..."
    cd "$COMPOSE_DIR"
    
    # Run model updater
    docker-compose -f docker-compose.llm.yml run --rm model-updater
    
    log "Model update completed."
}

# Main execution
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            build_images
            deploy_services
            test_deployment
            show_status
            ;;
        "build")
            check_prerequisites
            build_images
            ;;
        "up")
            deploy_services
            ;;
        "down")
            cd "$COMPOSE_DIR"
            docker-compose -f docker-compose.llm.yml down
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "update")
            force_update
            ;;
        "restart")
            cd "$COMPOSE_DIR"
            docker-compose -f docker-compose.llm.yml restart
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  deploy   - Build images and deploy all services (default)"
            echo "  build    - Build Docker images only"
            echo "  up       - Start services"
            echo "  down     - Stop services"
            echo "  status   - Show service status"
            echo "  logs     - Show recent logs"
            echo "  update   - Force model update"
            echo "  restart  - Restart all services"
            echo "  help     - Show this help message"
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
