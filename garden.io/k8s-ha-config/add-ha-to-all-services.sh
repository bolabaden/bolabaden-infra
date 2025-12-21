#!/bin/bash
# Add HA configuration to all Garden.io service files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

echo "=== Adding HA Configuration to All Services ==="

# Find all Deploy service files
find garden.io -name "*.garden.yml" -type f | while read file; do
  if grep -q "kind: Deploy" "$file"; then
    # Check if already has HA config
    if ! grep -q "replicas:" "$file" && ! grep -q "antiAffinity:" "$file"; then
      echo "Adding HA to: $file"
      
      # Add replicas and anti-affinity after spec: section
      if grep -q "^spec:" "$file"; then
        # Add after spec: line
        sed -i '/^spec:/a\
  replicas: 3\
  strategy:\
    type: RollingUpdate\
    rollingUpdate:\
      maxSurge: 1\
      maxUnavailable: 0\
  template:\
    spec:\
      affinity:\
        podAntiAffinity:\
          preferredDuringSchedulingIgnoredDuringExecution:\
          - weight: 100\
            podAffinityTerm:\
              labelSelector:\
                matchExpressions:\
                - key: app\
                  operator: In\
                  values:\
                  - ${self.name}\
              topologyKey: kubernetes.io/hostname' "$file"
      fi
    fi
  fi
done

echo "✅ HA configuration added to services"
