#!/bin/bash
# Backup configuration files

BACKUP_DIR="/mnt/local/backups/$(date +%Y%m%d_%H%M%S)"
CONFIG_PATH="${CONFIG_PATH:-./configs}"

echo "Creating backup directory: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

echo "Backing up configuration files..."
if [ -d "${CONFIG_PATH}" ]; then
  cp -rv "${CONFIG_PATH}" "${BACKUP_DIR}/"
  echo "Backup completed: ${BACKUP_DIR}"
else
  echo "Config directory not found: ${CONFIG_PATH}"
  exit 1
fi

# Keep only last 7 days of backups
find /mnt/local/backups -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo "Backup process complete"