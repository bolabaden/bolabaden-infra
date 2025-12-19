#!/bin/bash
# Run firecrawl and its dependencies
set -e

NOMAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAR_FILE="${NOMAD_DIR}/variables.auto.tfvars.hcl"
SECRETS_FILE="${NOMAD_DIR}/secrets.auto.tfvars.hcl"

echo "Starting firecrawl dependencies..."
# Start dependencies first
nomad job run -var-file="$VAR_FILE" -var-file="$SECRETS_FILE" "${NOMAD_DIR}/jobs/redis.nomad.hcl" || true
nomad job run -var-file="$VAR_FILE" -var-file="$SECRETS_FILE" "${NOMAD_DIR}/jobs/nuq-postgres.nomad.hcl" || true
nomad job run -var-file="$VAR_FILE" -var-file="$SECRETS_FILE" "${NOMAD_DIR}/jobs/playwright-service.nomad.hcl" || true

echo "Waiting for dependencies to be healthy..."
sleep 10

echo "Starting firecrawl..."
nomad job run -var-file="$VAR_FILE" -var-file="$SECRETS_FILE" "${NOMAD_DIR}/jobs/firecrawl.nomad.hcl"
