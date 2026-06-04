#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_ROOT="${CONFIG_PATH:-${ROOT_DIR}/volumes}"
SECRETS_ROOT="${SECRETS_PATH:-${ROOT_DIR}/secrets}"

CROWDSEC_CONTAINER_NAME="${CROWDSEC_CONTAINER_NAME:-crowdsec}"
CROWDSEC_BOUNCER_NAME="${CROWDSEC_BOUNCER_NAME:-traefik-bouncer}"
CROWDSEC_WAIT_SECONDS="${CROWDSEC_WAIT_SECONDS:-180}"

TRAEFIK_ROOT="${CONFIG_ROOT}/traefik"
CROWDSEC_ROOT="${TRAEFIK_ROOT}/crowdsec"
LAPI_KEY_FILE="${SECRETS_ROOT}/crowdsec-lapi-key.txt"

mkdir -p "${SECRETS_ROOT}"
mkdir -p "${TRAEFIK_ROOT}/logs"
mkdir -p "${CROWDSEC_ROOT}/data"
mkdir -p "${CROWDSEC_ROOT}/etc/crowdsec"
mkdir -p "${CROWDSEC_ROOT}/plugins"
mkdir -p "${CROWDSEC_ROOT}/var/log"

touch "${CROWDSEC_ROOT}/var/log/auth.log"
touch "${CROWDSEC_ROOT}/var/log/syslog"

if [[ ! -s "${LAPI_KEY_FILE}" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24 > "${LAPI_KEY_FILE}"
  else
    head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' > "${LAPI_KEY_FILE}"
  fi
fi

chmod 600 "${LAPI_KEY_FILE}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found; host paths and key file are prepared."
  exit 0
fi

if ! docker inspect "${CROWDSEC_CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "${CROWDSEC_CONTAINER_NAME} container not found; host paths and key file are prepared."
  exit 0
fi

deadline=$(( $(date +%s) + CROWDSEC_WAIT_SECONDS ))
while true; do
  if docker exec "${CROWDSEC_CONTAINER_NAME}" cscli lapi status >/dev/null 2>&1; then
    break
  fi
  if (( $(date +%s) >= deadline )); then
    echo "timeout waiting for CrowdSec LAPI"
    exit 1
  fi
  sleep 2
done

lapi_key="$(tr -d '[:space:]' < "${LAPI_KEY_FILE}")"
if [[ -z "${lapi_key}" ]]; then
  echo "empty CrowdSec LAPI key"
  exit 1
fi

if ! docker exec "${CROWDSEC_CONTAINER_NAME}" cscli bouncers list -o raw | grep -q "^${CROWDSEC_BOUNCER_NAME},"; then
  docker exec "${CROWDSEC_CONTAINER_NAME}" cscli bouncers add "${CROWDSEC_BOUNCER_NAME}" -k "${lapi_key}" >/dev/null 2>&1 || true
fi

docker exec "${CROWDSEC_CONTAINER_NAME}" cscli bouncers list -o raw | grep -q "^${CROWDSEC_BOUNCER_NAME},"

echo "CrowdSec bootstrap completed"