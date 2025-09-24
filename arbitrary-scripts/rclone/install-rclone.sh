#!/bin/bash

# install-rclone-unified.sh
# This script provides functionality for:
# 1. Installing and configuring systemd services for mounting rclone cloud storage
# 2. Installing and configuring systemd services for serving rclone storage over NFS
# It requires root privileges to run

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper function for logging
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_exec() {
    echo -e "${CYAN}[EXEC]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (use \`sudo -E $0 $1\`)"
fi

# Check if rclone is installed, install if not
if ! command -v rclone &> /dev/null; then
    log "rclone is not installed. Installing now..."
    curl https://rclone.org/install.sh | bash
    
    if ! command -v rclone &> /dev/null; then
        error "Failed to install rclone. Please install it manually: https://rclone.org/install/"
    else
        log "rclone installed successfully!"
    fi
else
    log "rclone is already installed, continuing..."
fi

# Get project root (always relative to script location)
PROJECT_ROOT=$(dirname "$(dirname "$(readlink -f "$0")")")
if [ ! -d "$PROJECT_ROOT" ]; then
    error "Could not determine project root directory"
fi

# Function to check if files are hardlinked to each other
check_hardlinks() {
    local file1="$1"
    local file2="$2"
    local file3="$3"
    
    # Check if all files exist
    if [ ! -f "$file1" ] || [ ! -f "$file2" ] || [ ! -f "$file3" ]; then
        return 1
    fi
    
    # Get inode numbers
    local inode1=$(stat -c %i "$file1")
    local inode2=$(stat -c %i "$file2")
    local inode3=$(stat -c %i "$file3")
    
    # Check if all inodes are the same (meaning they are hardlinked to each other)
    if [ "$inode1" = "$inode2" ] && [ "$inode2" = "$inode3" ]; then
        return 0
    fi
    
    return 1
}

# Function to handle rclone config hardlinking
setup_rclone_config() {
    local user_config="/home/brunner56/.config/rclone/rclone.conf"
    local root_config="/root/.config/rclone/rclone.conf"
    local project_config="$PROJECT_ROOT/configs/rclone/config/rclone/rclone.conf"
    
    # Debug logging
    log "Checking for config files:"
    log "Project config: $project_config"
    log "User config: $user_config"
    log "Root config: $root_config"
    [ -f "$project_config" ] && log "Project config exists" || log "Project config missing"
    [ -f "$user_config" ] && log "User config exists" || log "User config missing"
    [ -f "$root_config" ] && log "Root config exists" || log "Root config missing"
    
    # Check if at least one config file exists (in priority order)
    if [ ! -f "$project_config" ] && [ ! -f "$user_config" ] && [ ! -f "$root_config" ]; then
        error "No rclone config found. Please configure rclone first with \`rclone config\`."
    fi
    
    # Determine the source file based on priority
    local source_file=""
    if [ -f "$user_config" ]; then
        source_file="$user_config"
    elif [ -f "$root_config" ]; then
        source_file="$root_config"
    elif [ -f "$project_config" ]; then
        source_file="$project_config"
    fi
    
    # Check if files are properly hardlinked
    if ! check_hardlinks "$user_config" "$root_config" "$project_config"; then
        log "Configuring rclone config hardlinks..."
        
        # Create necessary directories
        mkdir -p "$(dirname "$user_config")"
        mkdir -p "$(dirname "$root_config")"  # Note: Might be the same as user_config
        mkdir -p "$(dirname "$project_config")"
        
        # Create hardlinks from the source file based on priority order
        if [ -f "$project_config" ]; then
            # Project exists, use it as source
            rm -f "$user_config" "$root_config"
            ln "$project_config" "$user_config" 2>/dev/null || cp "$project_config" "$user_config"
            ln "$project_config" "$root_config" 2>/dev/null || cp "$project_config" "$root_config"
        elif [ -f "$user_config" ]; then
            # User exists, use it as source
            rm -f "$project_config" "$root_config"
            ln "$user_config" "$project_config" 2>/dev/null || cp "$user_config" "$project_config"
            ln "$user_config" "$root_config" 2>/dev/null || cp "$user_config" "$root_config"
        else
            # Root exists (we know this because we checked earlier that at least one exists)
            rm -f "$project_config" "$user_config"
            ln "$root_config" "$project_config" 2>/dev/null || cp "$root_config" "$project_config"
            ln "$root_config" "$user_config" 2>/dev/null || cp "$root_config" "$user_config"
        fi
        
        log "Created hardlinks for rclone config"
    else
        log "Rclone config files are already properly hardlinked"
    fi
}

# Setup rclone config hardlinks
setup_rclone_config

# Function to configure FUSE for allow_other (used by mount functionality)
configure_fuse() {
    log "Configuring FUSE for allow_other..."
    
    # Check if file exists, create if it doesn't
    if [ ! -f /etc/fuse.conf ]; then
        touch /etc/fuse.conf
    fi

    # Check if user_allow_other exists (ignoring comments and whitespace)
    if ! grep -q "^[[:space:]]*user_allow_other[[:space:]]*$" /etc/fuse.conf; then
        # If it doesn't exist, append it
        echo "user_allow_other" | tee -a /etc/fuse.conf
        log "Added user_allow_other to /etc/fuse.conf"
    else
        log "user_allow_other already exists in /etc/fuse.conf"
    fi
}

# Function to check if a directory is mounted (used by mount functionality)
is_mounted() {
    mount | grep -q "$1"
}

# Function to safely unmount a directory (used by mount functionality)
safe_unmount() {
    if is_mounted "$1"; then
        log "Unmounting existing mount at $1..."
        fusermount -uqz "$1" || warn "Failed to unmount $1"
    else
        log "No existing mount found at $1"
    fi
}

# Function to create and configure a mount service
create_mount_service() {
    local name=$1
    echo "Name: $name"
    local remote=$2
    echo "Remote: $remote"
    local mount_point="$3"
    echo "Mount point: $mount_point"
    local service_name="rclone-mount-${name}"
    echo "Service name: $service_name"
    local service_file="/etc/systemd/system/${service_name}.service"
    echo "Service file: $service_file"
    local log_file="/var/log/rclone-${name}.log"
    echo "Log file: $log_file"

    log "Creating mount point directory at ${mount_point}..."
    mkdir -p "${mount_point}"

    # Safely unmount any existing mount
    safe_unmount "${mount_point}"
    echo "Unmounted ${mount_point} (if it was mounted)"
    systemctl stop rclone-mount-$(basename $MOUNT_POINT) -q > /dev/null 2>&1 || true
    systemctl disable rclone-mount-$(basename $MOUNT_POINT) -q > /dev/null 2>&1 || true
    echo "Disabled rclone-mount-$(basename $MOUNT_POINT) (if it was enabled)"
    log "Deleting old service files..."
    rm -vf /etc/systemd/system/rclone-mount-$(basename $MOUNT_POINT).service
    rm -vf /etc/systemd/system/multi-user.target.wants/rclone-mount-$(basename $MOUNT_POINT).service
    log "Creating systemd service file for ${name}..."
    local rclone_command=(
        /usr/bin/rclone mount "${remote}" "${mount_point}"
        --allow-other
        --attr-timeout 1s
        --cache-dir "/tmp/rclone-cache/${name}"
        --dir-cache-time 5m
        --log-level DEBUG
        --poll-interval 10s
        --umask 002
        --vfs-cache-mode full
        --exclude "*.accdb"
        --exclude "*.cdb"
        --exclude "*.db"
        --exclude "*.dbf"
        --exclude "*.dta"
        --exclude "*.fdb"
        --exclude "*.frm"
        --exclude "*.gdb"
        --exclude "*.h2.db"
        --exclude "*.ibd"
        --exclude "*.kexi"
        --exclude "*.ldf"
        --exclude "*.mdb"
        --exclude "*.mdf"
        --exclude "*.mv.db"
        --exclude "*.myd"
        --exclude "*.myi"
        --exclude "*.ndf"
        --exclude "*.nsf"
        --exclude "*.odb"
        --exclude "*.ora"
        --exclude "*.pdx"
        --exclude "*.rdb"
        --exclude "*.sdb"
        --exclude "*.sdf"
        --exclude "*.sqlite"
        --exclude "*.sqlite3"
        --exclude "*.sqlitedb"
        --exclude "*.wdb"
    )
    echo "Mount command: ${rclone_command[*]}"
    echo ""
    local prestart_command=(
        "rm -rf /tmp/rclone-cache-${name} > /dev/null 2>&1 || true &&"
        "mkdir -p /tmp/rclone-cache-${name} > /dev/null 2>&1 || true &&"
        "/bin/bash -c 'if mount | grep -q '${mount_point}'; then fusermount -uqz '${mount_point}'; fi' &&"
        "/bin/bash -c 'if [ -d ${mount_point} ] && [ -n \"\$(ls -A ${mount_point})\" ]; then rclone copy ${mount_point} cloudunion/${name} --delete-excluded --fast-list && rm -rf ${mount_point}; fi' &&"
        "mkdir -p ${mount_point} > /dev/null 2>&1 || true &&"
        "/bin/bash -c 'if mount | grep -q '${mount_point}'; then fusermount -uqz '${mount_point}'; fi'"
    )
    echo "Prestart command: ${prestart_command[@]}"
    /bin/bash -c "${prestart_command[*]}" > /dev/null 2>&1 || true
    echo ""
    local stop_command=(
        "if mount | grep -q '${mount_point}'; then fusermount -uqz '${mount_point}'; fi"
    )
    echo "Stop command: ${stop_command[@]}"
    echo ""
    cat > "${service_file}" << EOL
[Unit]
Description=Rclone Mount Service for ${name}
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
StandardOutput=journal
StandardError=journal
LogLevelMax=debug
Environment=HOME=/root
Environment=RCLONE_CONFIG=/root/.config/rclone/rclone.conf
ExecStart=/bin/bash -c "${rclone_command[@]}"

# Make sure the mount point exists
# disabled due to a bug and confusion on the syntax.
#ExecStartPre=/bin/bash -c "${prestart_command[@]}"

# Properly unmount on service stop
ExecStop=/bin/bash -c "${stop_command[@]}"

Restart=on-failure
RestartSec=10
User=root
Group=root
TimeoutStartSec=1800
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOL

    # Set proper permissions for the service file
    chmod 644 "${service_file}"

    # Create log file and set permissions
    touch "${log_file}"
    chmod 644 "${log_file}"

    # Enable and start the service
    log "Enabling and starting service ${service_name}..."
    systemctl daemon-reload
    log "Reloaded daemon"
    systemctl enable "${service_name}"
    log "Enabled service. Starting service (may take a while depending on the size of the mount point)..."
    systemctl start "${service_name}"
    log "Started service"

    # Check service status and show logs if it failed
    if systemctl is-active "${service_name}"; then
        log "Service ${service_name} is running successfully!"
    else
        error "Service ${service_name} failed to start. Check logs with:\n  journalctl -u ${service_name} -n 50"
    fi
}

# Convert relative path to absolute path
if [[ "$1" = /* ]]; then
    CALLER_DIR=$(realpath "$1")
else
    # Get the directory where the script was called from and resolve the relative path
    CALLER_DIR=$(pwd)
    CALLER_DIR=$(realpath "$CALLER_DIR/$1")
fi

MOUNT_POINT=$CALLER_DIR
# Mount functionality
# Get the mount point - either from command line argument or default to PROJECT_ROOT/data
if [ -n "$1" ]; then
    if [ ! -d "$MOUNT_POINT" ]; then
        warn "Directory '$MOUNT_POINT' does not exist. It will be created automatically."
        mkdir -p "$MOUNT_POINT"
    fi
else
    MOUNT_POINT="$PROJECT_ROOT/data"
    if [ ! -d "$MOUNT_POINT" ]; then
        warn "Directory '$MOUNT_POINT' does not exist. It will be created automatically."
        mkdir -p "$MOUNT_POINT"
    fi
fi

log "Using mount point: $MOUNT_POINT"
log "Using project root directory: $PROJECT_ROOT"

# Configure FUSE
configure_fuse

# Create services for mount
log "Setting up mount of $MOUNT_POINT..."
create_mount_service $(basename "$MOUNT_POINT") "cloudunion:$MOUNT_POINT" "$MOUNT_POINT"

log "All services have been configured!"
log "You can check their status with:"
echo "    sudo systemctl status rclone-mount-$(basename $MOUNT_POINT)"
log "View logs with:"
echo "    sudo journalctl -u rclone-mount-$(basename $MOUNT_POINT) -f"
log "To list all rclone-mount services, run:"
echo "    sudo systemctl list-units --type=service --all | grep rclone-mount"
log "To disable the service, run:"
echo "    sudo systemctl disable rclone-mount-$(basename $MOUNT_POINT)"
log "To enable the service, run:"
echo "    sudo systemctl enable rclone-mount-$(basename $MOUNT_POINT)"
log "To remove and delete the service (ensure it's stopped first!), run:"
echo "    sudo rm /etc/systemd/system/rclone-mount-$(basename $MOUNT_POINT).service"
echo "    sudo rm /etc/systemd/system/multi-user.target.wants/rclone-mount-$(basename $MOUNT_POINT).service"
