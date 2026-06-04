#!/bin/bash
set -euo pipefail

# Verification script for Constellation Agent
# This script verifies that the agent is properly installed and configured

echo "=== Constellation Agent Verification ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

check() {
    local name="$1"
    local command="$2"
    
    echo -n "Checking $name... "
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAILED++))
        return 1
    fi
}

check_warn() {
    local name="$1"
    local command="$2"
    
    echo -n "Checking $name... "
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        return 1
    fi
}

# Check if agent binary exists
check "Agent binary exists" "test -f /usr/local/bin/constellation-agent"

# Check if agent binary is executable
check "Agent binary is executable" "test -x /usr/local/bin/constellation-agent"

# Check if systemd service exists
check "Systemd service exists" "test -f /etc/systemd/system/constellation-agent.service"

# Check if systemd service is enabled
check_warn "Systemd service is enabled" "systemctl is-enabled constellation-agent.service"

# Check if agent is running
check_warn "Agent is running" "systemctl is-active constellation-agent.service"

# Check if required directories exist
check "Data directory exists" "test -d /opt/constellation/data"
check "Volumes directory exists" "test -d /opt/constellation/volumes"
check "Secrets directory exists" "test -d /opt/constellation/secrets"

# Check if Raft directories exist
check "Raft logs directory exists" "test -d /opt/constellation/data/raft/logs"
check "Raft stable directory exists" "test -d /opt/constellation/data/raft/stable"
check "Raft snapshots directory exists" "test -d /opt/constellation/data/raft/snapshots"

# Check if secrets exist
check_warn "Cloudflare API token exists" "test -f /opt/constellation/secrets/cf-api-token.txt"

# Check if secrets have correct permissions
if [ -f /opt/constellation/secrets/cf-api-token.txt ]; then
    PERMS=$(stat -c "%a" /opt/constellation/secrets/cf-api-token.txt)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
        echo -e "Checking secret permissions... ${GREEN}✓ PASSED${NC}"
        ((PASSED++))
    else
        echo -e "Checking secret permissions... ${YELLOW}⚠ WARNING (should be 600 or 400, got $PERMS)${NC}"
    fi
fi

# Check if Docker is running
check "Docker is running" "systemctl is-active docker.service"

# Check if Tailscale is running
check_warn "Tailscale is running" "systemctl is-active tailscaled.service || tailscale status >/dev/null 2>&1"

# Check if ports are available (if agent not running)
if ! systemctl is-active constellation-agent.service >/dev/null 2>&1; then
    check_warn "Gossip port (7946) is available" "! netstat -tuln | grep -q ':7946'"
    check_warn "Raft port (8300) is available" "! netstat -tuln | grep -q ':8300'"
    check_warn "HTTP provider port (8081) is available" "! netstat -tuln | grep -q ':8081'"
fi

# Check if agent can be built (if Go is available)
if command -v go >/dev/null 2>&1; then
    echo -n "Checking agent can be built... "
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if cd "$PROJECT_ROOT/infra" && go build -o /tmp/constellation-agent-test ./cmd/agent >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        rm -f /tmp/constellation-agent-test
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAILED++))
    fi
fi

# Check environment variables
echo ""
echo "=== Environment Variables ==="
ENV_VARS=("TS_HOSTNAME" "DOMAIN" "PUBLIC_IP" "CONFIG_PATH" "SECRETS_PATH" "DATA_DIR" "CLOUDFLARE_ZONE_ID")
for var in "${ENV_VARS[@]}"; do
    if [ -n "${!var:-}" ]; then
        echo -e "${GREEN}✓${NC} $var is set"
    else
        echo -e "${YELLOW}⚠${NC} $var is not set (may use default)"
    fi
done

# Check agent logs for errors (if running)
if systemctl is-active constellation-agent.service >/dev/null 2>&1; then
    echo ""
    echo "=== Recent Agent Logs ==="
    journalctl -u constellation-agent -n 20 --no-pager || true
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All critical checks passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some checks failed. Please review the output above.${NC}"
    exit 1
fi

