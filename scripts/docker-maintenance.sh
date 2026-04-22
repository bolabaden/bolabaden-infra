#!/bin/bash
#
# Docker Maintenance Script
# Prevents disk space issues by cleaning up Docker resources, logs, and caches
# Run via cron: 0 2 * * 0 (weekly at 2 AM on Sundays)
#

set -euo pipefail

LOG_FILE="/var/log/docker-maintenance.log"
MAX_LOG_SIZE=10485760  # 10MB

# Rotate log if it gets too big
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
    gzip "$LOG_FILE.old"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "========================================="
log "Starting Docker maintenance"
log "========================================="

# Get initial disk usage
INITIAL_USAGE=$(df -h / | awk 'NR==2 {print $5}')
log "Initial disk usage: $INITIAL_USAGE"

# 1. Stop containers that have been running for more than 30 days (optional - disabled by default)
# Uncomment to enable:
# log "Checking for long-running containers..."
# docker ps --filter "status=running" --format "{{.ID}} {{.Names}} {{.RunningFor}}" | \
#   awk '/months|days/ {if ($3 > 30) print $1}' | xargs -r docker stop

# 2. Remove stopped containers older than 7 days
log "Removing stopped containers older than 7 days..."
docker container prune -f --filter "until=168h" 2>&1 | tee -a "$LOG_FILE"

# 3. Remove unused images (keep images used in last 30 days)
log "Removing unused images..."
docker image prune -a -f --filter "until=720h" 2>&1 | tee -a "$LOG_FILE"

# 4. Remove unused volumes (be careful with this)
log "Removing unused volumes..."
docker volume prune -f --filter "label!=keep" 2>&1 | tee -a "$LOG_FILE"

# 5. Remove unused networks
log "Removing unused networks..."
docker network prune -f 2>&1 | tee -a "$LOG_FILE"

# 6. Remove build cache older than 7 days
log "Removing build cache older than 7 days..."
docker builder prune -a -f --filter "until=168h" 2>&1 | tee -a "$LOG_FILE"

# 7. Clean up Docker logs
log "Truncating Docker container logs larger than 100MB..."
find /var/lib/docker/containers -name "*.log" -type f -size +100M -exec truncate -s 50M {} \; 2>&1 | tee -a "$LOG_FILE"

# 7b. Clean up application logs under /opt/docker/data (e.g. homepage.log)
if [ -d "/opt/docker/data" ]; then
    log "Truncating large application logs in /opt/docker/data/*/logs/ (>100MB)..."
    find /opt/docker/data -path "*/logs/*.log" -type f -size +100M -exec truncate -s 50M {} \; 2>&1 | tee -a "$LOG_FILE"
fi

# 7c. Compact large SQLite DBs (e.g. stremthru.db) via VACUUM to reclaim space
STREMTHRU_DB="/opt/docker/data/stremio/addons/stremthru/app/data/stremthru.db"
if [ -f "$STREMTHRU_DB" ] && [ "$(stat -c%s "$STREMTHRU_DB" 2>/dev/null)" -gt 209715200 ] && command -v sqlite3 &>/dev/null; then
    # Only when DB > 200MB; VACUUM may fail if container holds lock (then we try again next run)
    log "Compacting stremthru.db (SQLite VACUUM)..."
    sqlite3 "$STREMTHRU_DB" "VACUUM;" 2>&1 | tee -a "$LOG_FILE" || true
    if [ "${PIPESTATUS[0]:-1}" -eq 0 ]; then
        log "stremthru.db compacted successfully"
    else
        log "stremthru.db VACUUM skipped or failed (database may be in use; will retry next week)"
    fi
fi

# 8. Clean up specific application caches
log "Cleaning application caches..."

# Prometheus WAL cleanup (keep last 7 days)
if [ -d "/opt/docker/data/prometheus/data/wal" ]; then
    log "Cleaning Prometheus WAL..."
    find /opt/docker/data/prometheus/data/wal -type f -mtime +7 -delete 2>&1 | tee -a "$LOG_FILE"
fi

# Stremio cache cleanup (keep last 30 days, limit to 10GB)
if [ -d "/opt/docker/data/stremio" ]; then
    log "Cleaning Stremio cache..."
    find /opt/docker/data/stremio -type f -mtime +30 -delete 2>&1 | tee -a "$LOG_FILE"
    # If still too large, remove oldest files
    STREMIO_SIZE=$(du -sm /opt/docker/data/stremio 2>/dev/null | cut -f1)
    if [ "${STREMIO_SIZE:-0}" -gt 10240 ]; then
        log "Stremio cache exceeds 10GB ($STREMIO_SIZE MB), removing oldest files..."
        find /opt/docker/data/stremio -type f -printf '%T+ %p\n' | sort | head -n 1000 | cut -d' ' -f2- | xargs -r rm -f
    fi
fi

# VictoriaMetrics data cleanup (keep last 60 days)
if [ -d "/opt/docker/data/victoriametrics/data" ]; then
    log "Cleaning VictoriaMetrics old data..."
    find /opt/docker/data/victoriametrics/data -type f -mtime +60 -delete 2>&1 | tee -a "$LOG_FILE"
fi

# Open-WebUI cache cleanup
if [ -d "/opt/docker/data/open-webui/cache" ]; then
    log "Cleaning Open-WebUI cache..."
    # Keep embedding models, but clean temporary files
    find /opt/docker/data/open-webui/cache -type f -name "*.tmp" -delete 2>&1 | tee -a "$LOG_FILE"
    find /opt/docker/data/open-webui/cache -type f -mtime +14 ! -path "*/models/*" -delete 2>&1 | tee -a "$LOG_FILE"
fi

# 9. Clean system package caches
log "Cleaning system package caches..."
if command -v apt-get &> /dev/null; then
    apt-get clean 2>&1 | tee -a "$LOG_FILE"
fi

# NPM cache (limit to 1GB)
if [ -d "/root/.npm" ]; then
    NPM_SIZE=$(du -sm /root/.npm 2>/dev/null | cut -f1)
    if [ "${NPM_SIZE:-0}" -gt 1024 ]; then
        log "NPM cache exceeds 1GB, cleaning..."
        npm cache clean --force 2>&1 | tee -a "$LOG_FILE" || true
    fi
fi

# Python UV cache (limit to 2GB)
if [ -d "/root/.cache/uv" ]; then
    UV_SIZE=$(du -sm /root/.cache/uv 2>/dev/null | cut -f1)
    if [ "${UV_SIZE:-0}" -gt 2048 ]; then
        log "UV cache exceeds 2GB, cleaning..."
        rm -rf /root/.cache/uv/archive-v0/* 2>&1 | tee -a "$LOG_FILE" || true
    fi
fi

# 10. Clean journalctl logs (keep last 30 days)
log "Cleaning system logs..."
journalctl --vacuum-time=30d 2>&1 | tee -a "$LOG_FILE"

# 11. Clean old log files
log "Removing old compressed logs..."
find /var/log -type f -name "*.gz" -mtime +30 -delete 2>&1 | tee -a "$LOG_FILE"
find /var/log -type f -name "*.log.*" -mtime +30 -delete 2>&1 | tee -a "$LOG_FILE"

# 12. Clean temporary files
log "Cleaning temporary files..."
find /tmp -type f -mtime +7 -delete 2>&1 | tee -a "$LOG_FILE" || true

# Get final disk usage
FINAL_USAGE=$(df -h / | awk 'NR==2 {print $5}')
log "Final disk usage: $FINAL_USAGE (was $INITIAL_USAGE)"

# Show Docker disk usage
log "Current Docker disk usage:"
docker system df 2>&1 | tee -a "$LOG_FILE"

log "========================================="
log "Docker maintenance completed"
log "========================================="

