#!/usr/bin/env bash
set -euo pipefail

# Runs the OpenSVC/Docker-driven Traefik failover config generator.
# Intended to be executed on each node.
#
# Requirements:
# - OpenSVC installed (`om` available)
# - Docker installed
# - `.env` contains DOMAIN, TS_HOSTNAME, CONFIG_PATH (as used by this repo)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

python3 "${ROOT_DIR}/scripts/osvc_ingress_sync.py"


