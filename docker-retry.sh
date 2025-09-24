#!/usr/bin/env bash
#
# docker-retry.sh — retry wrapper for Docker CLI
#
# Usage:
#   ./docker-retry.sh compose up -d --remove-orphans --build
#   ./docker-retry.sh ps
#   ./docker-retry.sh pull ubuntu:latest
#
# It will keep retrying the docker command until it succeeds.

set -euo pipefail

# Make sure Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker not found in PATH" >&2
    exit 127
fi

# Retry loop
attempt=1
while true; do
    echo "[docker-retry] Attempt #$attempt: docker $*"
    if docker "$@"; then
        echo "[docker-retry] Success after $attempt attempt(s)."
        break
    else
        echo "[docker-retry] Command failed (exit $?). Retrying in 3s..."
        attempt=$((attempt + 1))
        sleep 3
    fi
done
