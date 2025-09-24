#!/bin/sh
# Containerized Health Checker
# Monitors all backend servers and updates routing accordingly

set -e

# Configuration
CHECK_INTERVAL=${CHECK_INTERVAL:-30}
FAILURE_THRESHOLD=${FAILURE_THRESHOLD:-3}
SERVERS_FILE="/servers.conf"
LOG_FILE="/var/log/health-checker.log"

echo "Starting Health Checker"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Failure threshold: $FAILURE_THRESHOLD"

# Install required packages
apk add --no-cache curl jq

# Load server list
if [ ! -f "$SERVERS_FILE" ]; then
    echo "ERROR: Servers configuration file not found: $SERVERS_FILE"
    exit 1
fi

# Function to check server health
check_server() {
    local server=$1
    local port=${2:-443}
    local protocol=${3:-https}
    
    # Try to connect to the server
    if curl -s --max-time 10 --connect-timeout 5 "$protocol://$server:$port/health" >/dev/null 2>&1; then
        return 0  # Server is healthy
    else
        return 1  # Server is unhealthy
    fi
}

# Function to update routing based on health status
update_routing() {
    local healthy_servers="$1"
    
    # Update CoreDNS configuration with healthy servers only
    cat > /etc/coredns/zones/healthy-servers.conf << EOF
# Auto-generated healthy servers configuration
*.bolabaden.org {
    forward . $healthy_servers
    log
    health
}
EOF
    
    # Reload CoreDNS configuration
    if command -v coredns >/dev/null 2>&1; then
        # Send SIGHUP to reload configuration
        pkill -HUP coredns
    fi
    
    echo "$(date): Updated routing with healthy servers: $healthy_servers" >> "$LOG_FILE"
}

# Main health check loop
main() {
    while true; do
        echo "$(date): Starting health check cycle"
        
        healthy_servers=""
        total_servers=0
        healthy_count=0
        
        # Read servers from configuration file
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments and empty lines
            case "$line" in
                \#*|"") continue ;;
            esac
            
            total_servers=$((total_servers + 1))
            server=$(echo "$line" | awk '{print $1}')
            port=$(echo "$line" | awk '{print $2}')
            protocol=$(echo "$line" | awk '{print $3}')
            
            # Default values
            port=${port:-443}
            protocol=${protocol:-https}
            
            echo "Checking server: $server:$port ($protocol)"
            
            # Check server health
            if check_server "$server" "$port" "$protocol"; then
                echo "✓ $server is healthy"
                healthy_count=$((healthy_count + 1))
                if [ -n "$healthy_servers" ]; then
                    healthy_servers="$healthy_servers $server:$port"
                else
                    healthy_servers="$server:$port"
                fi
            else
                echo "✗ $server is unhealthy"
            fi
        done < "$SERVERS_FILE"
        
        # Update routing with healthy servers
        if [ -n "$healthy_servers" ]; then
            update_routing "$healthy_servers"
            echo "$(date): Health check complete. $healthy_count/$total_servers servers healthy" >> "$LOG_FILE"
        else
            echo "$(date): WARNING: No healthy servers found!" >> "$LOG_FILE"
        fi
        
        # Wait for next check
        sleep "$CHECK_INTERVAL"
    done
}

# Start main loop
main 