#!/bin/bash
# Update all Garden.io service configurations with HA settings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

echo "=== Updating All Services for High Availability ==="
echo ""

UPDATED=0
SKIPPED=0

# Find all Deploy service files
find garden.io -name "*.garden.yml" -type f | while read file; do
  if grep -q "kind: Deploy" "$file"; then
    SERVICE_NAME=$(grep "^name:" "$file" | head -1 | awk '{print $2}')
    
    # Check if it's a container Deploy (not Build)
    if grep -q "type: container" "$file"; then
      # Check if already has replicas configured
      if ! grep -q "replicas:" "$file"; then
        echo "Updating $SERVICE_NAME..."
        
        # Add replicas to spec section if it exists
        if grep -q "^spec:" "$file"; then
          # Check if there's already a replicas line we missed
          if ! grep -A 5 "^spec:" "$file" | grep -q "replicas:"; then
            # Add replicas after spec:
            sed -i '/^spec:/a\  replicas: 3' "$file"
            UPDATED=$((UPDATED + 1))
          else
            SKIPPED=$((SKIPPED + 1))
          fi
        fi
      else
        SKIPPED=$((SKIPPED + 1))
      fi
    fi
  fi
done

echo ""
echo "✅ Updated $UPDATED services"
echo "⏭️  Skipped $SKIPPED services (already configured)"
