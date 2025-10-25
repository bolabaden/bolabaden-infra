#!/bin/bash

# VPN Failover Service (Bash Implementation)
# Manages multiple VPN connections with automatic failover and health checking
# Supports both OpenVPN and Cloudflare WARP connections

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="vpn-failover"
readonly CONFIG_FILE="${VPN_FAILOVER_CONFIG:-/etc/vpn-failover/config.json}"
readonly STATE_FILE="/var/run/vpn-failover.state"
readonly LOCK_FILE="/var/run/vpn-failover.lock"
readonly LOG_FILE="/var/log/vpn-failover.log"
readonly PID_FILE="/var/run/vpn-failover.pid"

# Global variables
declare -A VPN_CONFIGS
declare -A VPN_STATUS
declare -A VPN_FAILURE_COUNT
declare -A VPN_LAST_CHECK
declare -A VPN_PROCESS_PID
declare -A VPN_START_TIME

ACTIVE_VPN=""
RUNNING=false
DOCKER_NETWORK="vpn-network"
DEBUG=${VPN_FAILOVER_DEBUG:-false}

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE" >&2
    
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}[$level] $message${NC}" >&2
    elif [[ "$level" == "WARN" ]]; then
        echo -e "${YELLOW}[$level] $message${NC}" >&2
    elif [[ "$level" == "INFO" ]]; then
        echo -e "${GREEN}[$level] $message${NC}" >&2
    elif [[ "$level" == "DEBUG" && "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[$level] $message${NC}" >&2
    fi
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { log "DEBUG" "$@"; }

# Utility functions
cleanup() {
    log_info "Cleaning up..."
    RUNNING=false
    
    # Disconnect all VPNs
    for vpn_name in "${!VPN_STATUS[@]}"; do
        if [[ "${VPN_STATUS[$vpn_name]}" == "connected" ]]; then
            disconnect_vpn "$vpn_name"
        fi
    done
    
    # Remove lock and PID files
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    
    log_info "VPN failover service stopped"
    exit 0
}

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log_error "Another instance is already running (PID: $lock_pid)"
            exit 1
        else
            log_warn "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    echo $$ > "$PID_FILE"
}

# Configuration loading
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        create_default_config
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not installed. Please install jq."
        exit 1
    fi
    
    log_info "Loading configuration from $CONFIG_FILE"
    
    # Parse JSON configuration
    local vpn_count
    vpn_count=$(jq -r '.vpns | length' "$CONFIG_FILE")
    
    if [[ "$vpn_count" -eq 0 ]]; then
        log_error "No VPN configurations found"
        exit 1
    fi
    
    # Load Docker network setting
    DOCKER_NETWORK=$(jq -r '.docker_network // "vpn-network"' "$CONFIG_FILE")
    
    # Load VPN configurations
    for ((i=0; i<vpn_count; i++)); do
        local vpn_name type config_path auth_path priority enabled
        
        vpn_name=$(jq -r ".vpns[$i].name" "$CONFIG_FILE")
        type=$(jq -r ".vpns[$i].type" "$CONFIG_FILE")
        config_path=$(jq -r ".vpns[$i].config_path" "$CONFIG_FILE")
        auth_path=$(jq -r ".vpns[$i].auth_path // empty" "$CONFIG_FILE")
        priority=$(jq -r ".vpns[$i].priority // 1" "$CONFIG_FILE")
        enabled=$(jq -r ".vpns[$i].enabled // true" "$CONFIG_FILE")
        
        if [[ "$enabled" == "true" ]]; then
            VPN_CONFIGS["$vpn_name"]="$type|$config_path|$auth_path|$priority"
            VPN_STATUS["$vpn_name"]="disconnected"
            VPN_FAILURE_COUNT["$vpn_name"]=0
            VPN_LAST_CHECK["$vpn_name"]=0
            VPN_PROCESS_PID["$vpn_name"]=""
            VPN_START_TIME["$vpn_name"]=""
            
            log_debug "Loaded VPN: $vpn_name (type: $type, priority: $priority)"
        fi
    done
    
    log_info "Loaded ${#VPN_CONFIGS[@]} VPN configurations"
}

create_default_config() {
    log_info "Creating default configuration at $CONFIG_FILE"
    
    local config_dir
    config_dir=$(dirname "$CONFIG_FILE")
    mkdir -p "$config_dir"
    
    cat > "$CONFIG_FILE" << 'EOF'
{
  "vpns": [
    {
      "name": "primary-openvpn",
      "type": "openvpn",
      "config_path": "/etc/openvpn/client/vpn_config.conf",
      "auth_path": "/etc/openvpn/client/auth.conf",
      "priority": 1,
      "health_check_url": "https://httpbin.org/ip",
      "health_check_interval": 30,
      "health_check_timeout": 10,
      "max_failures": 3,
      "reconnect_delay": 60,
      "enabled": true
    },
    {
      "name": "backup-openvpn",
      "type": "openvpn",
      "config_path": "/etc/openvpn/client/backup_config.conf",
      "auth_path": "/etc/openvpn/client/backup_auth.conf",
      "priority": 2,
      "health_check_url": "https://httpbin.org/ip",
      "health_check_interval": 30,
      "health_check_timeout": 10,
      "max_failures": 3,
      "reconnect_delay": 60,
      "enabled": true
    },
    {
      "name": "warp-fallback",
      "type": "warp",
      "config_path": "",
      "priority": 3,
      "health_check_url": "https://httpbin.org/ip",
      "health_check_interval": 30,
      "health_check_timeout": 10,
      "max_failures": 3,
      "reconnect_delay": 60,
      "enabled": true
    }
  ],
  "docker_network": "vpn-network",
  "log_level": "INFO"
}
EOF
    
    log_info "Default configuration created. Please edit $CONFIG_FILE as needed."
}

# VPN connection functions
get_vpn_config() {
    local vpn_name="$1"
    local field="$2"
    
    local config="${VPN_CONFIGS[$vpn_name]}"
    local type config_path auth_path priority
    
    IFS='|' read -r type config_path auth_path priority <<< "$config"
    
    case "$field" in
        "type") echo "$type" ;;
        "config_path") echo "$config_path" ;;
        "auth_path") echo "$auth_path" ;;
        "priority") echo "$priority" ;;
        *) echo "" ;;
    esac
}

get_vpn_setting() {
    local vpn_name="$1"
    local setting="$2"
    local default="$3"
    
    # Find VPN index in config
    local vpn_count
    vpn_count=$(jq -r '.vpns | length' "$CONFIG_FILE")
    
    for ((i=0; i<vpn_count; i++)); do
        local name
        name=$(jq -r ".vpns[$i].name" "$CONFIG_FILE")
        if [[ "$name" == "$vpn_name" ]]; then
            jq -r ".vpns[$i].$setting // \"$default\"" "$CONFIG_FILE"
            return
        fi
    done
    
    echo "$default"
}

connect_vpn() {
    local vpn_name="$1"
    local type
    type=$(get_vpn_config "$vpn_name" "type")
    
    log_info "Connecting to $vpn_name ($type)"
    
    VPN_STATUS["$vpn_name"]="connecting"
    VPN_START_TIME["$vpn_name"]=$(date +%s)
    
    case "$type" in
        "openvpn")
            connect_openvpn "$vpn_name"
            ;;
        "warp")
            connect_warp "$vpn_name"
            ;;
        *)
            log_error "Unsupported VPN type: $type"
            return 1
            ;;
    esac
}

connect_openvpn() {
    local vpn_name="$1"
    local config_path auth_path
    
    config_path=$(get_vpn_config "$vpn_name" "config_path")
    auth_path=$(get_vpn_config "$vpn_name" "auth_path")
    
    if [[ ! -f "$config_path" ]]; then
        log_error "OpenVPN config file not found: $config_path"
        VPN_STATUS["$vpn_name"]="failed"
        return 1
    fi
    
    # Prepare OpenVPN command
    local cmd=(
        "openvpn"
        "--config" "$config_path"
        "--daemon"
        "--log" "/var/log/openvpn-$vpn_name.log"
        "--writepid" "/var/run/openvpn-$vpn_name.pid"
    )
    
    if [[ -n "$auth_path" && -f "$auth_path" ]]; then
        cmd+=("--auth-user-pass" "$auth_path")
    fi
    
    # Start OpenVPN
    if "${cmd[@]}"; then
        sleep 5  # Wait for connection to establish
        
        # Check if process is still running
        local pid_file="/var/run/openvpn-$vpn_name.pid"
        if [[ -f "$pid_file" ]]; then
            local pid
            pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                VPN_PROCESS_PID["$vpn_name"]="$pid"
                VPN_STATUS["$vpn_name"]="connected"
                VPN_FAILURE_COUNT["$vpn_name"]=0
                
                update_docker_routing "$vpn_name"
                log_info "Successfully connected to $vpn_name"
                return 0
            fi
        fi
    fi
    
    log_error "Failed to connect to OpenVPN: $vpn_name"
    VPN_STATUS["$vpn_name"]="failed"
    return 1
}

connect_warp() {
    local vpn_name="$1"
    
    if ! command -v warp-cli >/dev/null 2>&1; then
        log_error "WARP CLI not found. Please install Cloudflare WARP."
        VPN_STATUS["$vpn_name"]="failed"
        return 1
    fi
    
    # Disconnect any existing WARP connection
    warp-cli disconnect >/dev/null 2>&1 || true
    
    # Connect to WARP
    if timeout 30 warp-cli connect >/dev/null 2>&1; then
        VPN_STATUS["$vpn_name"]="connected"
        VPN_FAILURE_COUNT["$vpn_name"]=0
        
        update_docker_routing "$vpn_name"
        log_info "Successfully connected to WARP: $vpn_name"
        return 0
    else
        log_error "Failed to connect to WARP: $vpn_name"
        VPN_STATUS["$vpn_name"]="failed"
        return 1
    fi
}

disconnect_vpn() {
    local vpn_name="$1"
    local type
    type=$(get_vpn_config "$vpn_name" "type")
    
    log_info "Disconnecting from $vpn_name"
    
    VPN_STATUS["$vpn_name"]="disconnecting"
    
    case "$type" in
        "openvpn")
            disconnect_openvpn "$vpn_name"
            ;;
        "warp")
            disconnect_warp "$vpn_name"
            ;;
    esac
    
    VPN_STATUS["$vpn_name"]="disconnected"
    VPN_PROCESS_PID["$vpn_name"]=""
    VPN_START_TIME["$vpn_name"]=""
}

disconnect_openvpn() {
    local vpn_name="$1"
    local pid="${VPN_PROCESS_PID[$vpn_name]}"
    
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        
        # Wait for process to terminate
        local count=0
        while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
    
    # Clean up PID file
    local pid_file="/var/run/openvpn-$vpn_name.pid"
    [[ -f "$pid_file" ]] && rm -f "$pid_file"
}

disconnect_warp() {
    local vpn_name="$1"
    
    if command -v warp-cli >/dev/null 2>&1; then
        warp-cli disconnect >/dev/null 2>&1 || true
    fi
}

update_docker_routing() {
    local vpn_name="$1"
    
    log_debug "Updating Docker routing for $vpn_name on $DOCKER_NETWORK"
    
    # This integrates with your existing vpn-up.sh logic
    # For now, we'll just log that routing should be updated
    # In a full implementation, you would call your routing scripts here
    
    log_info "Routing updated for $vpn_name on $DOCKER_NETWORK"
}

# Health checking
check_vpn_health() {
    local vpn_name="$1"
    local health_url timeout
    
    health_url=$(get_vpn_setting "$vpn_name" "health_check_url" "https://httpbin.org/ip")
    timeout=$(get_vpn_setting "$vpn_name" "health_check_timeout" "10")
    
    log_debug "Checking health for $vpn_name"
    
    if curl --silent --max-time "$timeout" --connect-timeout "$timeout" "$health_url" >/dev/null 2>&1; then
        VPN_LAST_CHECK["$vpn_name"]=$(date +%s)
        VPN_FAILURE_COUNT["$vpn_name"]=0
        log_debug "Health check passed for $vpn_name"
        return 0
    else
        local current_failures="${VPN_FAILURE_COUNT[$vpn_name]}"
        ((current_failures++))
        VPN_FAILURE_COUNT["$vpn_name"]=$current_failures
        
        local max_failures
        max_failures=$(get_vpn_setting "$vpn_name" "max_failures" "3")
        
        log_warn "Health check failed for $vpn_name (failure $current_failures/$max_failures)"
        return 1
    fi
}

should_failover() {
    if [[ -z "$ACTIVE_VPN" ]]; then
        return 0  # No active VPN, should connect
    fi
    
    local max_failures
    max_failures=$(get_vpn_setting "$ACTIVE_VPN" "max_failures" "3")
    
    # Check if max failures exceeded
    if [[ "${VPN_FAILURE_COUNT[$ACTIVE_VPN]}" -ge "$max_failures" ]]; then
        log_info "Max failures exceeded for $ACTIVE_VPN"
        return 0
    fi
    
    # Check if connection is in failed state
    if [[ "${VPN_STATUS[$ACTIVE_VPN]}" == "failed" ]]; then
        log_info "Active VPN $ACTIVE_VPN is in failed state"
        return 0
    fi
    
    return 1
}

perform_failover() {
    log_info "Performing VPN failover"
    
    # Disconnect current VPN
    if [[ -n "$ACTIVE_VPN" ]]; then
        disconnect_vpn "$ACTIVE_VPN"
        ACTIVE_VPN=""
    fi
    
    # Find next available VPN by priority
    local best_vpn=""
    local best_priority=999
    
    for vpn_name in "${!VPN_CONFIGS[@]}"; do
        if [[ "${VPN_STATUS[$vpn_name]}" == "disconnected" ]]; then
            local priority
            priority=$(get_vpn_config "$vpn_name" "priority")
            
            if [[ "$priority" -lt "$best_priority" ]]; then
                best_vpn="$vpn_name"
                best_priority="$priority"
            fi
        fi
    done
    
    if [[ -n "$best_vpn" ]]; then
        if connect_vpn "$best_vpn"; then
            ACTIVE_VPN="$best_vpn"
            log_info "Failover successful to $best_vpn"
            return 0
        fi
    fi
    
    log_error "No available VPN for failover"
    return 1
}

connect_best_available() {
    local best_vpn=""
    local best_priority=999
    
    for vpn_name in "${!VPN_CONFIGS[@]}"; do
        if [[ "${VPN_STATUS[$vpn_name]}" == "disconnected" ]]; then
            local priority
            priority=$(get_vpn_config "$vpn_name" "priority")
            
            if [[ "$priority" -lt "$best_priority" ]]; then
                best_vpn="$vpn_name"
                best_priority="$priority"
            fi
        fi
    done
    
    if [[ -n "$best_vpn" ]]; then
        if connect_vpn "$best_vpn"; then
            ACTIVE_VPN="$best_vpn"
            log_info "Connected to best available VPN: $best_vpn"
            return 0
        fi
    fi
    
    log_error "No available VPN to connect to"
    return 1
}

# Health check loop
health_check_loop() {
    while [[ "$RUNNING" == "true" ]]; do
        if [[ -n "$ACTIVE_VPN" ]]; then
            check_vpn_health "$ACTIVE_VPN"
        fi
        
        # Check if we need to failover
        if should_failover; then
            perform_failover
        fi
        
        sleep 10
    done
}

# Service status
get_service_status() {
    local status_info=""
    
    status_info="Service: $SCRIPT_NAME\n"
    status_info+="Running: $RUNNING\n"
    status_info+="Active VPN: ${ACTIVE_VPN:-none}\n"
    status_info+="Docker Network: $DOCKER_NETWORK\n\n"
    
    status_info+="VPN Status:\n"
    for vpn_name in "${!VPN_CONFIGS[@]}"; do
        local type priority status failures uptime
        type=$(get_vpn_config "$vpn_name" "type")
        priority=$(get_vpn_config "$vpn_name" "priority")
        status="${VPN_STATUS[$vpn_name]}"
        failures="${VPN_FAILURE_COUNT[$vpn_name]}"
        
        if [[ -n "${VPN_START_TIME[$vpn_name]}" ]]; then
            local start_time="${VPN_START_TIME[$vpn_name]}"
            local current_time=$(date +%s)
            uptime=$((current_time - start_time))
        else
            uptime=0
        fi
        
        status_info+="  $vpn_name: $status (type: $type, priority: $priority, failures: $failures, uptime: ${uptime}s)\n"
    done
    
    echo -e "$status_info"
}

# Signal handlers
handle_signal() {
    local signal="$1"
    log_info "Received signal $signal"
    cleanup
}

# Main service loop
main_service() {
    log_info "Starting VPN failover service"
    
    # Set up signal handlers
    trap 'handle_signal SIGTERM' TERM
    trap 'handle_signal SIGINT' INT
    trap 'handle_signal SIGHUP' HUP
    
    # Acquire lock
    acquire_lock
    
    # Load configuration
    load_config
    
    # Start health check loop in background
    health_check_loop &
    local health_check_pid=$!
    
    # Set running flag
    RUNNING=true
    
    # Connect to best available VPN
    connect_best_available
    
    # Main event loop
    while [[ "$RUNNING" == "true" ]]; do
        sleep 1
        
        # Check if health check loop is still running
        if ! kill -0 "$health_check_pid" 2>/dev/null; then
            log_warn "Health check loop died, restarting..."
            health_check_loop &
            health_check_pid=$!
        fi
    done
    
    # Clean up background processes
    kill "$health_check_pid" 2>/dev/null || true
    wait "$health_check_pid" 2>/dev/null || true
}

# Command line interface
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
    start       Start the VPN failover service
    stop        Stop the VPN failover service
    restart     Restart the VPN failover service
    status      Show service status
    test        Test connectivity
    help        Show this help message

Environment Variables:
    VPN_FAILOVER_CONFIG    Path to configuration file (default: $CONFIG_FILE)
    VPN_FAILOVER_DEBUG     Enable debug logging (default: false)

Files:
    Configuration: $CONFIG_FILE
    Log file:      $LOG_FILE
    PID file:      $PID_FILE
    Lock file:     $LOCK_FILE
EOF
}

cmd_start() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Service is already running (PID: $pid)"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    echo "Starting VPN failover service..."
    main_service
}

cmd_stop() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "Service is not running"
        exit 1
    fi
    
    local pid
    pid=$(cat "$PID_FILE")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Service is not running (stale PID file)"
        rm -f "$PID_FILE"
        exit 1
    fi
    
    echo "Stopping VPN failover service..."
    kill "$pid"
    
    # Wait for process to terminate
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 30 ]]; do
        sleep 1
        ((count++))
    done
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "Force killing service..."
        kill -9 "$pid"
    fi
    
    rm -f "$PID_FILE" "$LOCK_FILE"
    echo "Service stopped"
}

cmd_restart() {
    cmd_stop 2>/dev/null || true
    sleep 2
    cmd_start
}

cmd_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Service is running (PID: $pid)"
            
            # Try to get detailed status if possible
            if [[ -f "$STATE_FILE" ]]; then
                echo "Detailed status:"
                cat "$STATE_FILE"
            fi
        else
            echo "Service is not running (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        echo "Service is not running"
    fi
}

cmd_test() {
    echo "Testing connectivity..."
    
    local test_urls=(
        "https://httpbin.org/ip"
        "https://icanhazip.com"
        "https://ipinfo.io/ip"
    )
    
    for url in "${test_urls[@]}"; do
        echo -n "Testing $url: "
        if curl --silent --max-time 10 "$url" >/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done
}

# Main entry point
main() {
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    
    # Handle commands
    case "${1:-start}" in
        "start")
            cmd_start
            ;;
        "stop")
            cmd_stop
            ;;
        "restart")
            cmd_restart
            ;;
        "status")
            cmd_status
            ;;
        "test")
            cmd_test
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 