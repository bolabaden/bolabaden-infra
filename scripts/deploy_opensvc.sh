#!/bin/bash
set -e

# Ensure OpenSVC is installed
if ! command -v om &> /dev/null; then
    echo "OpenSVC (om) not found. Attempting install..."
    # Reuse install logic if needed, but assuming it's there
fi

for conf in opensvc_configs/*.conf; do
    [ -e "$conf" ] || continue
    svc_name=$(basename "$conf" .conf)
    echo "Deploying $svc_name from $conf..."
    
    # Check if service exists
    if sudo om "$svc_name" ls >/dev/null 2>&1; then
        echo "$svc_name exists. Recreating..."
        sudo om "$svc_name" stop --local || true
        sudo om "$svc_name" delete --local || true
    fi
    
    sudo om "$svc_name" create --config "$conf"
    echo "Starting $svc_name..."
    sudo om "$svc_name" start
done

echo "Deployment complete."

