#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

python3 "${ROOT_DIR}/scripts/osvc_l4_sync.py"


