#!/usr/bin/env bash
set -euo pipefail

# Repairs a known failure mode where Cloudflare WARP ends up in
# "RegistrationMissing" because /var/lib/cloudflare-warp/reg.json is present but
# empty/corrupt (0 bytes). In that case, the WARP container can incorrectly
# "skip registration" while the daemon cannot load registration.
#
# This script does NOT change any docker-compose YAML or environment variables.

CONTAINER_NAME="${1:-warp-nat-gateway}"
NETWORK_NAME="${2:-warp-nat-net}"
CHECK_IMAGE="${CHECK_IMAGE:-curlimages/curl}"

REG_PATH="/var/lib/cloudflare-warp/reg.json"
CONF_PATH="/var/lib/cloudflare-warp/conf.json"

echo "warp-fix: checking WARP registration state in '${CONTAINER_NAME}'..."

docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1 || {
  echo "warp-fix: container not found: ${CONTAINER_NAME}" >&2
  exit 1
}

file_size_in_container() {
  local path="$1"
  docker exec -u 0 "${CONTAINER_NAME}" sh -lc \
    "if [ -f '${path}' ]; then stat -c %s '${path}'; else echo -1; fi"
}

reg_size="$(file_size_in_container "${REG_PATH}")"
conf_size="$(file_size_in_container "${CONF_PATH}")"

echo "warp-fix: ${REG_PATH} size=${reg_size} bytes"
echo "warp-fix: ${CONF_PATH} size=${conf_size} bytes"

needs_repair="false"
if [ "${reg_size}" -eq 0 ] || [ "${conf_size}" -eq 0 ]; then
  needs_repair="true"
fi

if [ "${needs_repair}" = "true" ]; then
  echo "warp-fix: removing empty registration/config files and restarting..."
  docker exec -u 0 "${CONTAINER_NAME}" sh -lc \
    "rm -f '${REG_PATH}' '${CONF_PATH}' && sync || true"
  docker restart "${CONTAINER_NAME}" >/dev/null
  
  # Wait for container to be running after restart
  echo "warp-fix: waiting for ${CONTAINER_NAME} to be running..."
  for _ in $(seq 1 30); do
    state="$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo unknown)"
    if [ "${state}" = "running" ]; then
      break
    fi
    sleep 1
  done
  state="$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo unknown)"
  if [ "${state}" != "running" ]; then
    echo "warp-fix: container did not start (state=${state})" >&2
    docker logs --tail 200 "${CONTAINER_NAME}" >&2 || true
    exit 1
  fi
else
  echo "warp-fix: registration files look non-empty; no repair needed."
fi

# Wait for healthcheck to report healthy (if container has one)
if docker inspect -f '{{.State.Health.Status}}' "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "warp-fix: waiting for ${CONTAINER_NAME} to become healthy..."
  for _ in $(seq 1 45); do
    health="$(docker inspect -f '{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo unknown)"
    if [ "${health}" = "healthy" ]; then
      break
    fi
    sleep 2
  done
  health="$(docker inspect -f '{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo unknown)"
  if [ "${health}" != "healthy" ]; then
    echo "warp-fix: container did not become healthy (health=${health})" >&2
    docker logs --tail 200 "${CONTAINER_NAME}" >&2 || true
    exit 1
  fi
else
  # If no healthcheck, wait a bit for container to be ready after restart
  if [ "${needs_repair}" = "true" ]; then
    echo "warp-fix: waiting for ${CONTAINER_NAME} to be ready (no healthcheck configured)..."
    sleep 5
    # Verify container is still running
    state="$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo unknown)"
    if [ "${state}" != "running" ]; then
      echo "warp-fix: container is not running (state=${state})" >&2
      docker logs --tail 200 "${CONTAINER_NAME}" >&2 || true
      exit 1
    fi
  fi
fi

echo "warp-fix: validating WARP from network '${NETWORK_NAME}'..."

docker run --rm --network "${NETWORK_NAME}" --entrypoint sh "${CHECK_IMAGE}" -c \
  "curl -sS --max-time 8 https://cloudflare.com/cdn-cgi/trace | grep -qE '^warp=(on|plus)$'"

docker run --rm --network "${NETWORK_NAME}" --entrypoint sh "${CHECK_IMAGE}" -c \
  "curl -sS --max-time 12 https://registry.npmjs.org/pnpm/latest >/dev/null"

echo "warp-fix: OK (warp-nat-net egress + WARP active)"


