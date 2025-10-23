#!/bin/bash
# Bootstrap Helper - Manage bootstrap script configuration

set -euo pipefail

CONFIG_FILE="${BOOTSTRAP_CONFIG_FILE:-/etc/bootstrap-config.env}"

usage() {
    cat <<EOF
Bootstrap Helper - Manage bootstrap script configuration

Usage: $0 <command> [options]

Commands:
  config              Show current configuration
  validate            Validate configuration file
  create-config       Create config file from environment variables
  edit                Edit configuration file
  test                Test configuration by showing what would run
  
Examples:
  $0 config
  $0 validate
  $0 create-config
  $0 edit
  
Environment Variables:
  BOOTSTRAP_CONFIG_FILE   Config file location (default: /etc/bootstrap-config.env)

EOF
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: This command requires root privileges"
        exit 1
    fi
}

cmd_config() {
    echo "Bootstrap Configuration"
    echo "======================"
    echo "Config file: $CONFIG_FILE"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found. Using defaults and environment variables."
        echo ""
        echo "To create a config file:"
        echo "  sudo cp bootstrap-config.env.example $CONFIG_FILE"
        echo "  sudo nano $CONFIG_FILE"
        echo ""
        echo "Or run:"
        echo "  sudo $0 create-config"
        return
    fi

    echo "Current configuration:"
    echo "---"
    grep -v '^#' "$CONFIG_FILE" | grep -v '^$' || echo "(empty)"
    echo "---"
}

cmd_validate() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found: $CONFIG_FILE"
        echo "Using defaults - this is OK!"
        return 0
    fi

    echo "Validating configuration..."

    # Check for syntax errors
    if bash -n "$CONFIG_FILE" 2>&1; then
        echo "✓ Syntax is valid"
    else
        echo "✗ Syntax errors found"
        exit 1
    fi

    # Check for common issues
    source "$CONFIG_FILE" 2>/dev/null || true

    local warnings=0

    if [ "${ENABLE_TAILSCALE:-true}" = "true" ]; then
        if [ -z "${TAILSCALE_AUTH_KEY:-}" ] || [ "${TAILSCALE_AUTH_KEY}" = "your-auth-key-here" ]; then
            echo "⚠ TAILSCALE_AUTH_KEY is not set or uses default value"
            warnings=$((warnings + 1))
        fi
    fi

    if [ "${PASSWORD_HASH:-}" = '$6$pWurw/L0tau67C7g$kiM8cWIAg97/je2BQLKAm/FRuTz1Xu.g0UC59HuqK0d2jkLqw1FcDcB8YH.Iv0PEh3DhyMPosfmEWCi/AnmrX.' ]; then
        echo "⚠ PASSWORD_HASH uses default value - change this for security!"
        warnings=$((warnings + 1))
    fi

    if [ $warnings -eq 0 ]; then
        echo "✓ No warnings"
    else
        echo ""
        echo "Found $warnings warning(s)"
    fi
}

cmd_create_config() {
    check_root

    if [ -f "$CONFIG_FILE" ]; then
        echo "Config file already exists: $CONFIG_FILE"
        echo "Delete it first or use 'edit' command to modify it."
        exit 1
    fi

    echo "Creating configuration file: $CONFIG_FILE"

    # Find the example file
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    EXAMPLE_FILE="$SCRIPT_DIR/bootstrap-config.env.example"

    if [ ! -f "$EXAMPLE_FILE" ]; then
        echo "Error: Example configuration file not found: $EXAMPLE_FILE"
        exit 1
    fi

    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "✓ Configuration file created from example"
    echo ""
    echo "Edit the file to customize your settings:"
    echo "  nano $CONFIG_FILE"
}

cmd_edit() {
    check_root

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found. Creating from example..."
        cmd_create_config
    fi

    ${EDITOR:-nano} "$CONFIG_FILE"
}

cmd_test() {
    echo "Bootstrap Configuration Test"
    echo "============================"
    echo ""

    # Load config if it exists
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" 2>/dev/null || true

    echo "Configuration that will be used:"
    echo "---"
    echo "DOMAIN: ${DOMAIN:-bolabaden.org}"
    echo "PRIMARY_USER: ${PRIMARY_USER:-ubuntu}"
    echo "ADMIN_USERS: ${ADMIN_USERS:-root ubuntu}"
    echo "GITHUB_USERS: ${GITHUB_USERS:-th3w1zard1}"
    echo ""
    echo "DNS_SERVERS: ${DNS_SERVERS:-1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4}"
    echo ""
    echo "ENABLE_DOCKER: ${ENABLE_DOCKER:-true}"
    echo "ENABLE_TAILSCALE: ${ENABLE_TAILSCALE:-true}"
    echo "ENABLE_NOMAD: ${ENABLE_NOMAD:-true}"
    echo "ENABLE_CONSUL: ${ENABLE_CONSUL:-true}"
    echo ""
    echo "SWAP_SIZE: ${SWAP_SIZE:-4G}"
    echo "SWAP_FILE: ${SWAP_FILE:-/swapfile}"
    echo ""
    echo "SSH_PERMIT_ROOT: ${SSH_PERMIT_ROOT:-yes}"
    echo "SSH_PASSWORD_AUTH: ${SSH_PASSWORD_AUTH:-yes}"
    echo "---"
    echo ""
    echo "Run the bootstrap script with these settings:"
    echo "  sudo ./dont-run-directly.sh [hostname]"
}

# Main command dispatcher
case "${1:-}" in
config)
    cmd_config
    ;;
validate)
    cmd_validate
    ;;
create-config)
    cmd_create_config
    ;;
edit)
    cmd_edit
    ;;
test)
    cmd_test
    ;;
*)
    usage
    ;;
esac
