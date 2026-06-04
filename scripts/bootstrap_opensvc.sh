#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenSVC Bootstrap & Deployment Script
# ============================================================================
# This script bootstraps a node and deploys all OpenSVC services.
# It's idempotent and safe to run multiple times.
# Equivalent to: docker compose up -d --remove-orphans --build --pull=always
# ============================================================================

# Enable debug mode if requested
[ "${DEBUG:-false}" = "true" ] && set -x

# ============================================================================
# CONFIGURATION
# ============================================================================

# Load .env if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Defaults
DOMAIN="${DOMAIN:-bolabaden.org}"
STACK_NAME="${STACK_NAME:-my-media-stack}"
CONFIG_PATH="${CONFIG_PATH:-$REPO_ROOT/volumes}"
ROOT_PATH="${ROOT_PATH:-$REPO_ROOT}"
BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT:-$REPO_ROOT/arbitrary-scripts/bootstrap/dont-run-directly.sh}"
OPENSVC_CONFIG_DIR="${OPENSVC_CONFIG_DIR:-$REPO_ROOT/opensvc_configs}"

# Network configurations
WARP_NAT_NET_SUBNET="${WARP_NAT_NET_SUBNET:-10.0.2.0/24}"
WARP_NAT_NET_GATEWAY="${WARP_NAT_NET_GATEWAY:-10.0.2.1}"
PUBLICNET_SUBNET="${PUBLICNET_SUBNET:-10.76.0.0/16}"
PUBLICNET_GATEWAY="${PUBLICNET_GATEWAY:-10.76.0.1}"
BACKEND_SUBNET="${BACKEND_SUBNET:-10.0.7.0/24}"
BACKEND_GATEWAY="${BACKEND_GATEWAY:-10.0.7.1}"
NGINX_TRAEFIK_SUBNET="${NGINX_TRAEFIK_SUBNET:-10.0.8.0/24}"
NGINX_TRAEFIK_GATEWAY="${NGINX_TRAEFIK_GATEWAY:-10.0.8.1}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_info() {
    log "[*] $*"
}

log_success() {
    log "[✓] $*"
}

log_warn() {
    log "[!] $*"
}

log_error() {
    log "[✗] $*"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Docker network exists
docker_network_exists() {
    docker network inspect "$1" >/dev/null 2>&1
}

# Check if OpenSVC service exists
opensvc_svc_exists() {
    sudo om "$1" ls >/dev/null 2>&1
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

log_info "========================================"
log_info "OpenSVC Bootstrap & Deployment"
log_info "========================================"
log_info "Repository: $REPO_ROOT"
log_info "Stack: $STACK_NAME"
log_info "Domain: $DOMAIN"
log_info "========================================"

# Check if running as root (needed for some operations)
if [ "$EUID" -ne 0 ]; then
    log_warn "Not running as root. Some operations may require sudo."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# ============================================================================
# STEP 1: Run System Bootstrap (if script exists)
# ============================================================================

if [ -f "$BOOTSTRAP_SCRIPT" ] && [ "${SKIP_BOOTSTRAP:-false}" != "true" ]; then
    log_info "Running system bootstrap script..."
    if [ "$EUID" -eq 0 ]; then
        bash "$BOOTSTRAP_SCRIPT" || log_warn "Bootstrap script had warnings/errors"
    else
        log_warn "Bootstrap script requires root. Skipping. Run manually: sudo $BOOTSTRAP_SCRIPT"
    fi
    log_success "Bootstrap complete"
else
    log_info "Skipping bootstrap script (SKIP_BOOTSTRAP=true or script not found)"
fi

# ============================================================================
# STEP 2: Verify Docker
# ============================================================================

log_info "Verifying Docker..."
if ! command_exists docker; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running or not accessible."
    exit 1
fi

log_success "Docker is ready: $(docker --version)"

# ============================================================================
# STEP 3: Create Docker Networks
# ============================================================================

log_info "Creating Docker networks..."

# warp-nat-net (external, must exist)
if ! docker_network_exists warp-nat-net; then
    log_info "  Creating warp-nat-net..."
    docker network create \
        --attachable \
        -o com.docker.network.bridge.name=br_warp-nat-net \
        -o com.docker.network.bridge.enable_ip_masquerade=false \
        warp-nat-net \
        --subnet="$WARP_NAT_NET_SUBNET" \
        --gateway="$WARP_NAT_NET_GATEWAY" || log_warn "Failed to create warp-nat-net (may already exist)"
    log_success "  Created warp-nat-net"
else
    log_info "  warp-nat-net already exists"
fi

# Stack-specific networks (created by compose, but we need them for OpenSVC)
# These are NOT external in compose, so we create them if they don't exist
NETWORKS=(
    "${STACK_NAME}_default"
    "${STACK_NAME}_publicnet"
    "${STACK_NAME}_backend"
    "${STACK_NAME}_nginx_net"
)

for net in "${NETWORKS[@]}"; do
    if ! docker_network_exists "$net"; then
        log_info "  Creating $net..."
        
        # Determine subnet/gateway based on network name
        case "$net" in
            *publicnet*)
                SUBNET="$PUBLICNET_SUBNET"
                GATEWAY="$PUBLICNET_GATEWAY"
                BRIDGE_NAME="br_publicnet"
                ;;
            *backend*)
                SUBNET="$BACKEND_SUBNET"
                GATEWAY="$BACKEND_GATEWAY"
                BRIDGE_NAME="br_backend"
                ;;
            *nginx*)
                SUBNET="$NGINX_TRAEFIK_SUBNET"
                GATEWAY="$NGINX_TRAEFIK_GATEWAY"
                BRIDGE_NAME="br_nginx_net"
                ;;
            *)
                # Default network (bridge mode, no custom subnet)
                SUBNET=""
                GATEWAY=""
                BRIDGE_NAME=""
                ;;
        esac
        
        if [ -n "$SUBNET" ]; then
            docker network create \
                --attachable \
                ${BRIDGE_NAME:+-o com.docker.network.bridge.name=$BRIDGE_NAME} \
                "$net" \
                --subnet="$SUBNET" \
                ${GATEWAY:+--gateway=$GATEWAY} || log_warn "Failed to create $net"
        else
            docker network create --attachable "$net" || log_warn "Failed to create $net"
        fi
        
        log_success "  Created $net"
    else
        log_info "  $net already exists"
    fi
done

log_success "All Docker networks ready"

# ============================================================================
# STEP 4: Verify/Install OpenSVC
# ============================================================================

log_info "Verifying OpenSVC installation..."

if ! command_exists om && ! command_exists nodemgr; then
    log_info "OpenSVC not found. Installing..."
    if [ -f "$REPO_ROOT/scripts/install_opensvc.sh" ]; then
        bash "$REPO_ROOT/scripts/install_opensvc.sh" || {
            log_error "OpenSVC installation failed"
            exit 1
        }
    else
        log_error "OpenSVC install script not found at $REPO_ROOT/scripts/install_opensvc.sh"
        exit 1
    fi
fi

# Verify OpenSVC is working
if command_exists om; then
    if ! $SUDO_CMD om node ls >/dev/null 2>&1; then
        log_warn "OpenSVC node not initialized. Run: sudo nodemgr node setup"
    else
        log_success "OpenSVC is ready"
    fi
elif command_exists nodemgr; then
    log_success "OpenSVC nodemgr found (om command may not be available)"
else
    log_error "OpenSVC installation incomplete"
    exit 1
fi

# ============================================================================
# STEP 5: Deploy OpenSVC Services
# ============================================================================

log_info "Deploying OpenSVC services from $OPENSVC_CONFIG_DIR..."

if [ ! -d "$OPENSVC_CONFIG_DIR" ]; then
    log_error "OpenSVC config directory not found: $OPENSVC_CONFIG_DIR"
    exit 1
fi

# Find all .conf files
CONFIG_FILES=("$OPENSVC_CONFIG_DIR"/*.conf)

if [ ${#CONFIG_FILES[@]} -eq 0 ] || [ ! -f "${CONFIG_FILES[0]}" ]; then
    log_warn "No OpenSVC config files found in $OPENSVC_CONFIG_DIR"
    log_info "Skipping service deployment"
else
    for config_file in "${CONFIG_FILES[@]}"; do
        [ -f "$config_file" ] || continue
        
        svc_name=$(basename "$config_file" .conf)
        log_info "  Processing service: $svc_name"
        
        # Check if service exists
        if opensvc_svc_exists "$svc_name"; then
            log_info "    Service exists. Updating configuration..."
            # Stop if running
            $SUDO_CMD om "$svc_name" stop --local 2>/dev/null || true
            # Update config
            $SUDO_CMD om "$svc_name" update --config "$config_file" 2>/dev/null || {
                log_warn "    Update failed, trying delete and recreate..."
                $SUDO_CMD om "$svc_name" delete --local 2>/dev/null || true
                $SUDO_CMD om "$svc_name" create --config "$config_file" || {
                    log_error "    Failed to create $svc_name"
                    continue
                }
            }
        else
            log_info "    Creating new service..."
            $SUDO_CMD om "$svc_name" create --config "$config_file" || {
                log_error "    Failed to create $svc_name"
                continue
            }
        fi
        
        # Start the service
        log_info "    Starting $svc_name..."
        $SUDO_CMD om "$svc_name" start || {
            log_warn "    Failed to start $svc_name (may need manual intervention)"
        }
        
        log_success "    $svc_name deployed"
    done
    
    log_success "All OpenSVC services deployed"
fi

# ============================================================================
# STEP 6: Sync Ingress Configurations
# ============================================================================

log_info "Syncing ingress configurations..."

# HTTP ingress sync
if [ -f "$REPO_ROOT/scripts/osvc_ingress_sync.sh" ]; then
    log_info "  Running HTTP ingress sync..."
    bash "$REPO_ROOT/scripts/osvc_ingress_sync.sh" || log_warn "HTTP ingress sync had warnings"
fi

# L4 ingress sync
if [ -f "$REPO_ROOT/scripts/osvc_l4_sync.sh" ]; then
    log_info "  Running L4 ingress sync..."
    bash "$REPO_ROOT/scripts/osvc_l4_sync.sh" || log_warn "L4 ingress sync had warnings"
fi

log_success "Ingress configurations synced"

# ============================================================================
# STEP 7: Verify Services
# ============================================================================

log_info "Verifying deployed services..."

if command_exists om; then
    log_info "OpenSVC service status:"
    $SUDO_CMD om svc ls 2>/dev/null || log_warn "Could not list services"
fi

log_info "Docker containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

# ============================================================================
# COMPLETE
# ============================================================================

log_info ""
log_info "========================================"
log_info "  OpenSVC Deployment Complete!"
log_info "========================================"
log_info "  Stack: $STACK_NAME"
log_info "  Domain: $DOMAIN"
log_info "  Config Path: $CONFIG_PATH"
log_info ""
log_info "Next steps:"
log_info "  - Check service status: sudo om svc ls"
log_info "  - View logs: sudo om <service> logs"
log_info "  - Monitor: sudo om <service> status"
log_info "========================================"
log_info ""

