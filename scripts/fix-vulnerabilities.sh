#!/bin/bash
#
# Fix NPM and Python vulnerabilities across all subprojects
#

set -euo pipefail

LOG_FILE="/tmp/vulnerability-fixes.log"
> "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "============================================================"
log "Fixing Vulnerabilities Across All Subprojects"
log "============================================================"

# Track statistics
TOTAL_PROJECTS=0
FIXED_PROJECTS=0
FAILED_PROJECTS=0

# Function to fix npm vulnerabilities in a directory
fix_npm_vulnerabilities() {
    local dir="$1"
    local project_name=$(basename "$dir")
    
    if [ ! -f "$dir/package.json" ]; then
        return
    fi
    
    TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))
    
    log ""
    log "📦 Processing: $dir"
    
    cd "$dir"
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        log "   ⚠️  No node_modules, skipping..."
        return
    fi
    
    # Run audit
    if npm audit --production 2>&1 | grep -q "found 0 vulnerabilities"; then
        log "   ✅ No vulnerabilities found"
        FIXED_PROJECTS=$((FIXED_PROJECTS + 1))
        return
    fi
    
    log "   🔧 Fixing vulnerabilities..."
    
    # Try audit fix
    if npm audit fix --force >> "$LOG_FILE" 2>&1; then
        if npm audit --production 2>&1 | grep -q "found 0 vulnerabilities"; then
            log "   ✅ All vulnerabilities fixed!"
            FIXED_PROJECTS=$((FIXED_PROJECTS + 1))
        else
            local remaining=$(npm audit --production 2>&1 | grep "vulnerabilities" | head -1)
            log "   ⚠️  Partially fixed: $remaining"
            FIXED_PROJECTS=$((FIXED_PROJECTS + 1))
        fi
    else
        log "   ❌ Failed to fix"
        FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
    fi
}

# Function to update Python requirements
fix_python_vulnerabilities() {
    local dir="$1"
    
    if [ ! -f "$dir/requirements.txt" ]; then
        return
    fi
    
    log ""
    log "🐍 Processing Python: $dir"
    
    cd "$dir"
    
    # Check if this is installed
    if [ ! -d "venv" ] && [ ! -f ".venv/bin/python" ]; then
        log "   ⚠️  No venv, skipping..."
        return
    fi
    
    # Try to update with safety check (if available)
    if command -v safety &> /dev/null; then
        log "   🔧 Checking with safety..."
        safety check -r requirements.txt >> "$LOG_FILE" 2>&1 || true
    fi
    
    log "   ℹ️  Manual review recommended for Python dependencies"
}

# Main execution
cd /home/ubuntu/my-media-stack

log ""
log "Phase 1: Fixing NPM vulnerabilities..."
log "======================================"

# Find and fix all npm projects
find . -name "package.json" -not -path "*/node_modules/*" -type f | while read -r package_file; do
    project_dir=$(dirname "$package_file")
    fix_npm_vulnerabilities "$project_dir"
done

log ""
log "Phase 2: Checking Python dependencies..."
log "=========================================="

# Find and check Python projects
find . -name "requirements.txt" -not -path "*/venv/*" -not -path "*/.venv/*" -type f | while read -r req_file; do
    project_dir=$(dirname "$req_file")
    fix_python_vulnerabilities "$project_dir"
done

log ""
log "============================================================"
log "Summary"
log "============================================================"
log "Total NPM projects processed: $TOTAL_PROJECTS"
log "Successfully fixed/clean: $FIXED_PROJECTS"
log "Failed: $FAILED_PROJECTS"
log ""
log "Full log: $LOG_FILE"
log "============================================================"

echo ""
echo "Run 'git status' to see what changed."
echo "Then commit with: git add -A && git commit -m 'Fix security vulnerabilities'"

