#!/bin/bash
# Script to inline dashboard JSON files into docker-compose.metrics.yml

set -euo pipefail

COMPOSE_FILE="/home/ubuntu/my-media-stack/compose/docker-compose.metrics.yml"
DASHBOARDS_DIR="/home/ubuntu/my-media-stack/compose/dashboards"
TEMP_FILE="/tmp/metrics-with-dashboards.yml"

# Dashboard files to inline
DASHBOARDS=(
  "alert-overview.json"
  "alertmanager-monitoring.json"
  "application-performance.json"
  "container-monitoring.json"
  "database-monitoring.json"
  "infrastructure-overview.json"
  "log-analysis.json"
  "loki-monitoring.json"
  "network-monitoring.json"
  "process-monitoring.json"
  "prometheus-self-monitoring.json"
  "security-monitoring.json"
  "slo-error-budget.json"
  "victoriametrics-monitoring.json"
)

# Find the line number where we need to insert (after warp-net-init-dashboard.json, before loki.yaml)
INSERT_LINE=$(grep -n "^  loki.yaml:" "$COMPOSE_FILE" | head -1 | cut -d: -f1)

if [ -z "$INSERT_LINE" ]; then
  echo "Error: Could not find insertion point (loki.yaml:)"
  exit 1
fi

echo "Found insertion point at line $INSERT_LINE"

# Create temp file with content before insertion point
head -n $((INSERT_LINE - 1)) "$COMPOSE_FILE" > "$TEMP_FILE"

# Add each dashboard
for dashboard in "${DASHBOARDS[@]}"; do
  dashboard_path="$DASHBOARDS_DIR/$dashboard"
  
  if [ ! -f "$dashboard_path" ]; then
    echo "Warning: Dashboard not found: $dashboard_path"
    continue
  fi
  
  echo "Adding dashboard: $dashboard"
  
  # Add the dashboard config header
  echo "  $dashboard:" >> "$TEMP_FILE"
  echo "    content: |" >> "$TEMP_FILE"
  
  # Add the JSON content with proper indentation (6 spaces)
  while IFS= read -r line; do
    echo "      $line" >> "$TEMP_FILE"
  done < "$dashboard_path"
  
done

# Add the rest of the original file (from loki.yaml onwards)
tail -n +$INSERT_LINE "$COMPOSE_FILE" >> "$TEMP_FILE"

# Backup original file
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

# Replace original with new file
mv "$TEMP_FILE" "$COMPOSE_FILE"

echo "Successfully inlined $((${#DASHBOARDS[@]})) dashboards into $COMPOSE_FILE"
echo "Original file backed up"
