#!/bin/bash
# Script to run specific Nomad jobs
# Usage: ./run-job.sh <job-name> [job-name2 ...]
# Example: ./run-job.sh core firecrawl

set -e

NOMAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAR_FILE="${NOMAD_DIR}/variables.auto.tfvars.hcl"
SECRETS_FILE="${NOMAD_DIR}/secrets.auto.tfvars.hcl"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <job-name> [job-name2 ...]"
    echo ""
    echo "Available jobs:"
    ls -1 "${NOMAD_DIR}/jobs"/*.nomad.hcl 2>/dev/null | sed 's|.*/||' | sed 's|\.nomad\.hcl||' | sed 's|^|  - |' || echo "  No job files found in jobs/ directory"
    exit 1
fi

for job in "$@"; do
    job_file="${NOMAD_DIR}/jobs/${job}.nomad.hcl"
    
    if [ ! -f "$job_file" ]; then
        echo "Error: Job file not found: $job_file"
        exit 1
    fi
    
    echo "Running job: $job"
    nomad job run \
        -var-file="$VAR_FILE" \
        -var-file="$SECRETS_FILE" \
        "$job_file"
done
