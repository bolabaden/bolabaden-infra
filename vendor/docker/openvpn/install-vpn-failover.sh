#!/bin/bash

# VPN Failover Service Installation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="vpn-failover"
SERVICE_DIR="/etc/vpn-failover"
SERVICE_FILE="/etc/systemd/system/vpn-failover.service"
CONFIG_FILE="$SERVICE_DIR/config.json"

echo -e "${GREEN}Installing VPN Failover Service...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Create service directory
echo "Creating service directory..."
mkdir -p "$SERVICE_DIR"
mkdir -p /var/log/vpn-failover

# Copy service files
echo "Installing service files..."
cp vpn-failover-service.py "$SERVICE_DIR/"
chmod +x "$SERVICE_DIR/vpn-failover-service.py"

# Copy configuration
if [ -f "vpn-failover-config.json" ]; then
    cp vpn-failover-config.json "$CONFIG_FILE"
    echo -e "${GREEN}Configuration copied to $CONFIG_FILE${NC}"
else
    echo -e "${YELLOW}No configuration file found. Service will create default config on first run.${NC}"
fi

# Install systemd service
echo "Installing systemd service..."
cp vpn-failover.service "$SERVICE_FILE"
systemctl daemon-reload

# Set proper permissions
chown -R root:root "$SERVICE_DIR"
chmod 755 "$SERVICE_DIR"
chmod 644 "$CONFIG_FILE" 2>/dev/null || true

# Create log directory
mkdir -p /var/log/vpn-failover
touch /var/log/vpn-failover.log
chmod 644 /var/log/vpn-failover.log

# Install dependencies
echo "Checking dependencies..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python 3 is required but not installed.${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}curl not found. Installing...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl
    elif command -v yum &> /dev/null; then
        yum install -y curl
    elif command -v dnf &> /dev/null; then
        dnf install -y curl
    else
        echo -e "${RED}Could not install curl. Please install it manually.${NC}"
        exit 1
    fi
fi

# Check for OpenVPN
if ! command -v openvpn &> /dev/null; then
    echo -e "${YELLOW}OpenVPN not found. Installing...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y openvpn
    elif command -v yum &> /dev/null; then
        yum install -y openvpn
    elif command -v dnf &> /dev/null; then
        dnf install -y openvpn
    else
        echo -e "${RED}Could not install OpenVPN. Please install it manually.${NC}"
        exit 1
    fi
fi

# Check for Cloudflare WARP (optional)
if ! command -v warp-cli &> /dev/null; then
    echo -e "${YELLOW}Cloudflare WARP CLI not found.${NC}"
    echo "To install WARP, visit: https://developers.cloudflare.com/warp-client/get-started/linux/"
    echo "Or run: curl -fsSL https://pkg.cloudflareclient.com/install.sh | sh"
fi

# Enable and start service
echo "Enabling and starting service..."
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}VPN Failover Service installed and started successfully!${NC}"
else
    echo -e "${RED}Service failed to start. Check logs with: journalctl -u $SERVICE_NAME${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Service commands:"
echo "  Start:   systemctl start $SERVICE_NAME"
echo "  Stop:    systemctl stop $SERVICE_NAME"
echo "  Restart: systemctl restart $SERVICE_NAME"
echo "  Status:  systemctl status $SERVICE_NAME"
echo "  Logs:    journalctl -u $SERVICE_NAME -f"
echo ""
echo "Configuration file: $CONFIG_FILE"
echo "Service logs: /var/log/vpn-failover.log"
echo ""
echo -e "${YELLOW}Remember to configure your VPN configurations in $CONFIG_FILE${NC}" 