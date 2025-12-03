#!/bin/bash
#
# Setup cron jobs for automated maintenance
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up cron jobs for automated maintenance..."

# Create a temporary crontab file
TEMP_CRON=$(mktemp)

# Get existing crontab (if any), excluding our managed jobs
crontab -l 2>/dev/null | grep -v "docker-maintenance.sh" | grep -v "# MEDIA-STACK-MAINTENANCE" > "$TEMP_CRON" || true

# Add our maintenance jobs with markers
cat >> "$TEMP_CRON" << EOF

# MEDIA-STACK-MAINTENANCE: Automated maintenance jobs
# Docker cleanup - Weekly on Sundays at 2 AM
0 2 * * 0 $SCRIPT_DIR/docker-maintenance.sh >> /var/log/docker-maintenance.log 2>&1

# Docker cleanup (lighter) - Daily at 3 AM (only removes stopped containers and old logs)
0 3 * * * docker container prune -f --filter "until=168h" && journalctl --vacuum-time=30d >> /var/log/docker-maintenance.log 2>&1

# Check disk usage and alert - Daily at 4 AM
0 4 * * * df -h / | awk 'NR==2 {if (int(\$5) > 85) print "WARNING: Disk usage at " \$5}' >> /var/log/disk-usage.log 2>&1

EOF

# Install the new crontab
crontab "$TEMP_CRON"
rm "$TEMP_CRON"

echo "Cron jobs installed successfully!"
echo ""
echo "Scheduled jobs:"
echo "  - Weekly Docker maintenance: Sundays at 2:00 AM"
echo "  - Daily container cleanup: Every day at 3:00 AM"
echo "  - Daily disk usage check: Every day at 4:00 AM"
echo ""
echo "Current crontab:"
crontab -l | grep -A 10 "MEDIA-STACK-MAINTENANCE"

