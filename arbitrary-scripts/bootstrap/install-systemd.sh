#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Function to print colored output
print_status() {
    echo -e "\033[1;34m[*]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[!]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[+]\033[0m $1"
}

# Update package index
print_status "Updating package index..."
apk update

# Install systemd and related packages
print_status "Installing systemd and related packages..."
apk add --no-cache \
    systemd \
    systemd-dev \
    systemd-libs \
    systemd-utils \
    systemd-openrc \
    systemd-sysvcompat

# Enable systemd
print_status "Enabling systemd..."
echo "rc_system=systemd" >> /etc/rc.conf

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p /etc/systemd/system
mkdir -p /etc/systemd/user
mkdir -p /run/systemd

# Configure systemd
print_status "Configuring systemd..."
cat > /etc/systemd/system.conf << 'EOF'
[Manager]
DefaultStandardOutput=journal
DefaultStandardError=journal
DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=90s
DefaultRestartSec=100ms
DefaultStartLimitIntervalSec=10s
DefaultStartLimitBurst=5
DefaultCPUAccounting=no
DefaultIOAccounting=no
DefaultBlockIOAccounting=no
DefaultMemoryAccounting=no
DefaultTasksAccounting=no
DefaultTasksMax=4096
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65535
DefaultLimitNICE=0
DefaultLimitCORE=infinity
DefaultLimitMEMLOCK=65536
DefaultLimitLOCKS=infinity
DefaultLimitSIGPENDING=65535
DefaultLimitMSGQUEUE=819200
DefaultLimitRTPRIO=0
DefaultLimitRTTIME=infinity
EOF

# Configure journald
print_status "Configuring journald..."
cat > /etc/systemd/journald.conf << 'EOF'
[Journal]
Storage=persistent
SystemMaxUse=1G
SystemMaxFileSize=100M
RuntimeMaxUse=100M
RuntimeMaxFileSize=10M
ForwardToSyslog=yes
EOF

# Create systemd service directory
print_status "Creating systemd service directory..."
mkdir -p /etc/systemd/system/multi-user.target.wants

# Enable essential systemd services
print_status "Enabling essential systemd services..."
systemctl enable systemd-journald.service
systemctl enable systemd-sysctl.service
systemctl enable systemd-update-utmp.service
systemctl enable systemd-update-done.service
systemctl enable systemd-random-seed.service
systemctl enable systemd-machine-id-commit.service

# Create systemd machine ID if it doesn't exist
if [ ! -f /etc/machine-id ]; then
    print_status "Generating machine ID..."
    systemd-machine-id-setup
fi

# Update systemd
print_status "Updating systemd..."
systemctl daemon-reload

print_success "Systemd installation and configuration completed successfully!"
print_status "Please reboot your system to apply all changes."
print_status "After reboot, you can verify the installation with: systemctl --version" 