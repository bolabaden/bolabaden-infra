package main

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// ConfigFile represents a config file that needs to be created
type ConfigFile struct {
	Path        string // File path relative to configPath
	Content     string // Default content
	Permissions os.FileMode
}

// ensureConfigFiles creates all default config files if they don't exist
func ensureConfigFiles(configPath string) error {
	configs := getAllDefaultConfigs()

	for _, cfg := range configs {
		fullPath := filepath.Join(configPath, cfg.Path)

		// Check if file already exists
		if _, err := os.Stat(fullPath); err == nil {
			// File exists, skip
			continue
		}

		// Create directory if needed
		dir := filepath.Dir(fullPath)
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}

		// Write file with default content
		perm := cfg.Permissions
		if perm == 0 {
			perm = 0644 // Default permissions
		}
		if err := os.WriteFile(fullPath, []byte(cfg.Content), perm); err != nil {
			return fmt.Errorf("failed to write config file %s: %w", fullPath, err)
		}

		fmt.Printf("Created default config: %s\n", fullPath)
	}

	return nil
}

// getAllDefaultConfigs returns all default config files from docker-compose.yml configs blocks
func getAllDefaultConfigs() []ConfigFile {
	return []ConfigFile{
		// WARP NAT Routing configs (from docker-compose.warp-nat-routing.yml)
		{
			Path: "warp-nat-routing/warp-nat-setup.sh",
			Content: `#!/bin/bash
set -xe

# Defaults (configurable via env)
DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"
ROUTER_CONTAINER_NAME="${ROUTER_CONTAINER_NAME:-warp_router}"
DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME:-warp-nat-net}"
WARP_CONTAINER_NAME="${WARP_CONTAINER_NAME:-warp-nat-gateway}"
HOST_VETH_IP="${HOST_VETH_IP:-169.254.100.1}"
CONT_VETH_IP="${CONT_VETH_IP:-169.254.100.2}"
ROUTING_TABLE="${ROUTING_TABLE:-warp-nat-routing}"
VETH_HOST="${VETH_HOST:-veth-warp}" 

# VETH_CONT is derived from VETH_HOST
VETH_CONT="${VETH_HOST#veth-}-nat-cont"
DOCKER="docker -H $DOCKER_HOST"
DEFAULT_DOCKER_NETWORK_NAME="warp-nat-net"

echo "=========================================="
echo "Starting WARP NAT setup script"
echo "=========================================="

# ==========================================
# PHASE 1: COMPLETE CLEANUP OF OLD STATE
# ==========================================
echo ""
echo "Phase 1: Cleaning up any existing configuration..."

# Remove old veth interfaces
if ip link show "$VETH_HOST" >/dev/null 2>&1; then
    echo "Removing old veth interface: $VETH_HOST"
    ip link del "$VETH_HOST" 2>/dev/null || true
fi

# Get the subnet to clean up rules (try to get from network if it exists)
CLEANUP_SUBNET="${WARP_NAT_NET_SUBNET:-10.0.2.0/24}"
if $DOCKER network inspect "$DOCKER_NETWORK_NAME" >/dev/null 2>&1; then
    EXISTING_SUBNET=$($DOCKER network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$DOCKER_NETWORK_NAME" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$EXISTING_SUBNET" ]]; then
        CLEANUP_SUBNET="$EXISTING_SUBNET"
    fi
fi

# Remove old routing rules for this subnet
echo "Removing old routing rules for $CLEANUP_SUBNET"
while ip rule del from "$CLEANUP_SUBNET" table "$ROUTING_TABLE" 2>/dev/null; do
    echo "  Removed routing rule"
done

# Remove old iptables failsafe rules
echo "Removing old failsafe iptables rules"
while iptables -D FORWARD -s "$CLEANUP_SUBNET" -j DROP -m comment --comment "warp-nat-failsafe" 2>/dev/null; do
    echo "  Removed failsafe rule"
done

# Remove old NAT rules on host
echo "Removing old NAT rules on host"
iptables -t nat -D POSTROUTING -s "$CLEANUP_SUBNET" ! -d "$CLEANUP_SUBNET" -j MASQUERADE 2>/dev/null || true

echo "Phase 1 cleanup complete"

# Pick a free routing table id dynamically (start at 110)
pick_table_id() {
    local id=110
    while grep -q "^$id " /etc/iproute2/rt_tables 2>/dev/null; do
        id=$((id+1))
    done
    echo $id
}

# ==========================================
# PHASE 2: SETUP ROUTING TABLE
# ==========================================
echo ""
echo "Phase 2: Setting up routing table..."

# Get existing routing table ID if name exists, else pick new and add
if grep -q " $ROUTING_TABLE$" /etc/iproute2/rt_tables 2>/dev/null; then
    ROUTING_TABLE_ID=$(awk "/ $ROUTING_TABLE\$/ {print \$1}" /etc/iproute2/rt_tables)
    echo "Routing table exists: $ROUTING_TABLE (ID: $ROUTING_TABLE_ID)"
else
    ROUTING_TABLE_ID=$(pick_table_id)
    echo "$ROUTING_TABLE_ID $ROUTING_TABLE" >> /etc/iproute2/rt_tables
    echo "Created routing table: $ROUTING_TABLE (ID: $ROUTING_TABLE_ID)"
fi

# ==========================================
# PHASE 3: ENSURE NETWORK EXISTS AND DISCOVER WARP CONTAINER
# ==========================================
echo ""
echo "Phase 3: Ensuring network exists and discovering WARP container..."

# Get stack name from compose labels to construct proper network name
STACK_NAME="$(
    $DOCKER inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$ROUTER_CONTAINER_NAME" 2>/dev/null \
    || $DOCKER inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$WARP_CONTAINER_NAME" 2>/dev/null \
    || echo ""
)"

# Check if network exists using Compose naming pattern (stack_network) first
ACTUAL_NETWORK_NAME=""
if [[ -n "$STACK_NAME" ]]; then
    if $DOCKER network inspect "${STACK_NAME}_$DOCKER_NETWORK_NAME" >/dev/null 2>&1; then
        ACTUAL_NETWORK_NAME="${STACK_NAME}_$DOCKER_NETWORK_NAME"
    fi
fi

# Fallback: try plain network name
if [[ -z "$ACTUAL_NETWORK_NAME" ]]; then
    if $DOCKER network inspect "$DOCKER_NETWORK_NAME" >/dev/null 2>&1; then
        ACTUAL_NETWORK_NAME="$DOCKER_NETWORK_NAME"
    fi
fi

# Create network only if it doesn't exist
if [[ -z "$ACTUAL_NETWORK_NAME" ]]; then
    echo "Network $DOCKER_NETWORK_NAME does not exist, creating it..."
    BRIDGE_OPT_NAME="br_$DOCKER_NETWORK_NAME"
    $DOCKER network create \
        --driver=bridge \
        --attachable \
        -o com.docker.network.bridge.name="$BRIDGE_OPT_NAME" \
        -o com.docker.network.bridge.enable_ip_masquerade=false \
        --subnet="${WARP_NAT_NET_SUBNET:-10.0.2.0/24}" \
        --gateway="${WARP_NAT_NET_GATEWAY:-10.0.2.1}" \
        "$DOCKER_NETWORK_NAME"
    ACTUAL_NETWORK_NAME="$DOCKER_NETWORK_NAME"
    echo "Created network: $ACTUAL_NETWORK_NAME"
else
    echo "Found existing network: $ACTUAL_NETWORK_NAME"
fi

echo "Found network: $ACTUAL_NETWORK_NAME"

# Dynamically get network subnet
DOCKER_NET="$($DOCKER network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$ACTUAL_NETWORK_NAME" 2>/dev/null | tr -d '[:space:]')"
if [[ -z "$DOCKER_NET" ]]; then
    echo "Error: Could not determine subnet for network $ACTUAL_NETWORK_NAME"
    exit 1
fi
echo "Network subnet: $DOCKER_NET"

# Dynamically get the actual bridge name from the network
BRIDGE_NAME="$($DOCKER network inspect -f '{{index .Options "com.docker.network.bridge.name"}}' "$ACTUAL_NETWORK_NAME" 2>/dev/null)"
if [[ -z "$BRIDGE_NAME" || "$BRIDGE_NAME" == "<no value>" ]]; then
    NETWORK_ID="$($DOCKER network inspect -f '{{.Id}}' "$ACTUAL_NETWORK_NAME" 2>/dev/null | cut -c1-12)"
    BRIDGE_NAME="br-$NETWORK_ID"
    echo "Bridge name not explicitly set, using Docker default: $BRIDGE_NAME"
else
    echo "Bridge device: $BRIDGE_NAME"
fi

# Verify the bridge exists
if ! ip link show "$BRIDGE_NAME" >/dev/null 2>&1; then
    echo "Error: Bridge $BRIDGE_NAME does not exist"
    echo "Available bridges:"
    ip link show type bridge
    exit 1
fi

# Get WARP container PID
warp_pid="$($DOCKER inspect -f '{{.State.Pid}}' $WARP_CONTAINER_NAME 2>/dev/null || echo "")"
if [[ -z "$warp_pid" || "$warp_pid" == "0" ]]; then
    echo "Error: $WARP_CONTAINER_NAME container not found or not running"
    exit 1
fi

if [[ ! -e "/proc/$warp_pid/ns/net" ]]; then
    echo "Error: $WARP_CONTAINER_NAME container network namespace not ready"
    exit 1
fi

echo "Found WARP container PID: $warp_pid"

# Clean orphan NAT rules inside warp container
echo "Cleaning orphan NAT rules inside WARP container..."
nsenter -t "$warp_pid" -n iptables -t nat -S POSTROUTING 2>/dev/null | grep -- '-j MASQUERADE' | while read -r rule; do
    s_net=$(echo "$rule" | sed -n 's/.*-s \([^ ]*\) -j MASQUERADE.*/\1/p')
    if [[ -z "$s_net" ]]; then continue; fi
    if [[ "$s_net" == "$DOCKER_NET" ]]; then continue; fi
    echo "  Removing orphan NAT rule inside warp: $s_net"
    del_rule=$(echo "$rule" | sed 's/^-A/-D/')
    nsenter -t "$warp_pid" -n iptables -t nat $del_rule 2>/dev/null || true
done

# Set up cleanup function for error handling
cleanup() {
    echo "⚠️ Error occurred. Rolling back changes..."

    if ip link show "$VETH_HOST" >/dev/null 2>&1; then
        echo "Removing veth interface: $VETH_HOST"
        ip link del "$VETH_HOST" 2>/dev/null || true
    fi

    if ip rule show | grep -q "from $DOCKER_NET lookup $ROUTING_TABLE"; then
        echo "Removing routing rule: from $DOCKER_NET lookup $ROUTING_TABLE"
        ip rule del from "$DOCKER_NET" table "$ROUTING_TABLE" 2>/dev/null || true
    fi

    if ip route show table "$ROUTING_TABLE" | grep -q "^default via $CONT_VETH_IP dev $VETH_HOST"; then
        echo "Removing default route from $ROUTING_TABLE"
        ip route del default via "$CONT_VETH_IP" dev "$VETH_HOST" table "$ROUTING_TABLE" 2>/dev/null || true
    fi
    if ip route show table "$ROUTING_TABLE" | grep -q "^$DOCKER_NET dev $BRIDGE_NAME"; then
        echo "Removing network route from $ROUTING_TABLE"
        ip route del "$DOCKER_NET" dev "$BRIDGE_NAME" table "$ROUTING_TABLE" 2>/dev/null || true
    fi

    if iptables -t nat -C POSTROUTING -s "$DOCKER_NET" ! -d "$DOCKER_NET" -j MASQUERADE 2>/dev/null; then
        echo "Removing NAT rule on host"
        iptables -t nat -D POSTROUTING -s "$DOCKER_NET" ! -d "$DOCKER_NET" -j MASQUERADE 2>/dev/null || true
    fi

    if [[ -n "$warp_pid" ]] && [[ -e "/proc/$warp_pid/ns/net" ]]; then
        if nsenter -t "$warp_pid" -n iptables -t nat -C POSTROUTING -s "$DOCKER_NET" -j MASQUERADE 2>/dev/null; then
            echo "Removing NAT rule inside WARP container"
            nsenter -t "$warp_pid" -n iptables -t nat -D POSTROUTING -s "$DOCKER_NET" -j MASQUERADE 2>/dev/null || true
        fi
    fi
    
    if ! iptables -C FORWARD -s "$DOCKER_NET" -j DROP -m comment --comment "warp-nat-failsafe" 2>/dev/null; then
        echo "Re-enabling failsafe DROP rule to prevent IP leaks"
        iptables -I FORWARD -s "$DOCKER_NET" -j DROP -m comment --comment "warp-nat-failsafe" 2>/dev/null || true
    fi
}

# ==========================================
# PHASE 4: CRITICAL SETUP WITH FAILSAFE
# ==========================================
echo ""
echo "Phase 4: Setting up VETH tunnel and routing..."

trap cleanup ERR

echo "Installing failsafe DROP rule to prevent IP leaks during setup"
iptables -I FORWARD -s "$DOCKER_NET" -j DROP -m comment --comment "warp-nat-failsafe"

echo "Creating veth pair: $VETH_HOST <-> $VETH_CONT"
ip link add "$VETH_HOST" type veth peer name "$VETH_CONT"

echo "Moving $VETH_CONT into WARP container namespace"
ip link set "$VETH_CONT" netns "$warp_pid"

echo "Configuring host veth: $VETH_HOST ($HOST_VETH_IP/30)"
ip addr add "$HOST_VETH_IP/30" dev "$VETH_HOST"
ip link set "$VETH_HOST" up

echo "Configuring container veth: $VETH_CONT ($CONT_VETH_IP/30)"
nsenter -t "$warp_pid" -n ip addr add "$CONT_VETH_IP/30" dev "$VETH_CONT"
nsenter -t "$warp_pid" -n ip link set "$VETH_CONT" up
nsenter -t "$warp_pid" -n sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "Setting up NAT inside WARP container for $DOCKER_NET"
nsenter -t "$warp_pid" -n iptables -t nat -C POSTROUTING -s "$DOCKER_NET" -j MASQUERADE 2>/dev/null || \
nsenter -t "$warp_pid" -n iptables -t nat -A POSTROUTING -s "$DOCKER_NET" -j MASQUERADE

echo "Adding routing rule: from $DOCKER_NET lookup $ROUTING_TABLE"
ip rule add from "$DOCKER_NET" table "$ROUTING_TABLE"

echo "Configuring routes in routing table $ROUTING_TABLE"

if ip route show table "$ROUTING_TABLE" | grep -q "^$DOCKER_NET dev $BRIDGE_NAME"; then
    echo "  Removing existing network route for $DOCKER_NET"
    ip route del "$DOCKER_NET" dev "$BRIDGE_NAME" table "$ROUTING_TABLE" 2>/dev/null || true
fi

if ip route show table "$ROUTING_TABLE" | grep -q "^default via $CONT_VETH_IP dev $VETH_HOST"; then
    echo "  Removing existing default route"
    ip route del default via "$CONT_VETH_IP" dev "$VETH_HOST" table "$ROUTING_TABLE" 2>/dev/null || true
fi

echo "  Adding network route: $DOCKER_NET dev $BRIDGE_NAME"
ip route add "$DOCKER_NET" dev "$BRIDGE_NAME" table "$ROUTING_TABLE"
echo "  Adding default route: default via $CONT_VETH_IP dev $VETH_HOST"
ip route add default via "$CONT_VETH_IP" dev "$VETH_HOST" table "$ROUTING_TABLE"

echo "Setting up NAT on host for $DOCKER_NET"
iptables -t nat -C POSTROUTING -s "$DOCKER_NET" ! -d "$DOCKER_NET" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s "$DOCKER_NET" ! -d "$DOCKER_NET" -j MASQUERADE

echo "Removing failsafe DROP rule - routing is now active"
while iptables -D FORWARD -s "$DOCKER_NET" -j DROP -m comment --comment "warp-nat-failsafe" 2>/dev/null; do 
    echo "  Removed failsafe rule"
done

trap - ERR

echo ""
echo "=========================================="
echo "✅ WARP NAT setup complete"
echo "=========================================="
echo "Network:        $DOCKER_NETWORK_NAME"
echo "Subnet:         $DOCKER_NET"
echo "Veth host:      $VETH_HOST ($HOST_VETH_IP)"
echo "Veth container: $VETH_CONT ($CONT_VETH_IP)"
echo "Routing table:  $ROUTING_TABLE (ID: $ROUTING_TABLE_ID)"
echo "Bridge:         $BRIDGE_NAME"
echo "=========================================="
`,
			Permissions: 0700,
		},
		{
			Path: "warp-nat-routing/warp-monitor.sh",
			Content: `#!/usr/bin/env bash
set -euo pipefail

# Configurable via env
DOCKER_CMD="${DOCKER_CMD:-docker -H ${DOCKER_HOST:-unix:///var/run/docker.sock}}"
CHECK_IMAGE="${CHECK_IMAGE:-curlimages/curl}"
NETWORK="${NETWORK:-warp-nat-net}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-5}"

HEALTHCHECK_INSIDE='sh -c "if curl -s --max-time 4 https://cloudflare.com/cdn-cgi/trace | grep -qE \"^warp=on|warp=plus$\"; then echo WARP_OK && exit 0; else echo WARP_NOT_OK && exit 1; fi"'

echo "warp-monitor: checking WARP via ephemeral container on network '${NETWORK}'."
echo "Using image: ${CHECK_IMAGE}"
prev_ok=1
fail_count=0
RETRY_SETUP_AFTER="${RETRY_SETUP_AFTER:-12}"

while true; do
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] running health probe..."
  if ${DOCKER_CMD} run --rm --network "${NETWORK}" --entrypoint sh "${CHECK_IMAGE}" -c "${HEALTHCHECK_INSIDE}"; then
    if [[ "${prev_ok}" -eq 0 ]]; then
      echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] health probe recovered -> marking healthy"
    fi
    prev_ok=1
    fail_count=0
  else
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] health probe failed (consecutive failures: $((fail_count + 1)))"
    fail_count=$((fail_count + 1))
    
    if [[ "${prev_ok}" -eq 1 ]] || [[ "${fail_count}" -ge "${RETRY_SETUP_AFTER}" ]]; then
    if [[ "${prev_ok}" -eq 1 ]]; then
      echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] detected healthy->unhealthy transition; running /usr/local/bin/warp-nat-setup.sh"
      else
        echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] still unhealthy after $fail_count failures; retrying /usr/local/bin/warp-nat-setup.sh"
        fail_count=0
      fi
      if /usr/local/bin/warp-nat-setup.sh; then
        echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] warp-nat-setup.sh completed"
      else
        echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] warp-nat-setup.sh failed (exit nonzero)."
      fi
      prev_ok=0
      sleep "${SLEEP_INTERVAL}"
    else
      echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] still unhealthy ($fail_count failures); will retry setup after $RETRY_SETUP_AFTER consecutive failures"
    fi
  fi

  sleep "${SLEEP_INTERVAL}"
done
`,
			Permissions: 0700,
		},
		// Session Manager config (example from services.go)
		{
			Path: "projects/kotor/kotorscript-session-manager/session_manager.py",
			Content: `#!/usr/bin/env python3
# Session Manager - Default implementation
# This file should be customized for your use case
import os
import sys

def main():
    print("Session Manager starting...")
    # Add your session management logic here
    pass

if __name__ == "__main__":
    main()
`,
			Permissions: 0644,
		},
		// Watchtower config
		{
			Path: "watchtower/watchtower-config.json",
			Content: `{
  "interval": 3600,
  "cleanup": true,
  "include_stopped": false,
  "revive_stopped": false,
  "include_restarting": false,
  "rolling_restart": false,
  "monitor_only": false,
  "no_startup_message": false
}
`,
			Permissions: 0644,
		},
		// CrowdSec configs (from docker-compose.coolify-proxy.yml)
		{
			Path: "traefik/crowdsec/config.yaml",
			Content: `common:
  log_media: stdout
  log_level: info
  log_dir: /var/log/
config_paths:
  config_dir: /etc/crowdsec/
  data_dir: /var/lib/crowdsec/data/
  simulation_path: /etc/crowdsec/simulation.yaml
  hub_dir: /etc/crowdsec/hub/
  index_path: /etc/crowdsec/hub/.index.json
  notification_dir: /etc/crowdsec/notifications/
  plugin_dir: /usr/local/lib/crowdsec/plugins/
crowdsec_service:
  acquisition_path: /etc/crowdsec/acquis.yaml
  acquisition_dir: /etc/crowdsec/acquis.d
  parser_routines: 1
plugin_config:
  user: nobody
  group: nobody
cscli:
  output: human
db_config:
  log_level: info
  type: sqlite
  db_path: /var/lib/crowdsec/data/crowdsec.db
  flush:
    max_items: 5000
    max_age: 7d
  use_wal: false
api:
  client:
    insecure_skip_verify: false
    credentials_path: /etc/crowdsec/local_api_credentials.yaml
  server:
    log_level: info
    listen_uri: 0.0.0.0:8080
    profiles_path: /etc/crowdsec/profiles.yaml
    trusted_ips:
      - 127.0.0.1
      - ::1
    online_client:
      credentials_path: /etc/crowdsec//online_api_credentials.yaml
    enable: true
prometheus:
  enabled: true
  level: full
  listen_addr: 0.0.0.0
  listen_port: 6060
`,
			Permissions: 0644,
		},
		{
			Path: "traefik/crowdsec/acquis.yaml",
			Content: `filenames:
  - /var/log/auth.log
  - /var/log/syslog
labels:
  type: syslog
---
poll_without_inotify: false
filenames:
  - /var/log/traefik/*.log
labels:
  type: traefik
`,
			Permissions: 0644,
		},
		{
			Path: "traefik/crowdsec/profiles.yaml",
			Content: `name: default_ip_remediation
filters:
- Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
- type: ban
  duration: 4h
on_success: break
---
name: default_range_remediation
filters:
- Alert.Remediation == true && Alert.GetScope() == "Range"
decisions:
- type: ban
  duration: 4h
on_success: break
`,
			Permissions: 0644,
		},
		{
			Path: "traefik/crowdsec/notifications/victoriametrics.yaml",
			Content: `type: http
name: http_victoriametrics
log_level: debug
format: >
  {{- range $Alert := . -}}
  {{- $traefikRouters := GetMeta . "traefik_router_name" -}}
  {{- range .Decisions -}}
  {"metric":{"__name__":"cs_lapi_decision","instance":"my-instance","country":"{{$Alert.Source.Cn}}","asname":"{{$Alert.Source.AsName}}","asnumber":"{{$Alert.Source.AsNumber}}","latitude":"{{$Alert.Source.Latitude}}","longitude":"{{$Alert.Source.Longitude}}","iprange":"{{$Alert.Source.Range}}","scenario":"{{.Scenario}}","type":"{{.Type}}","duration":"{{.Duration}}","scope":"{{.Scope}}","ip":"{{.Value}}","traefik_routers":{{ printf "%q" ($traefikRouters | uniq | join ",")}}},"values": [1],"timestamps":[{{now|unixEpoch}}000]}
  {{- end }}
  {{- end -}}
url: http://victoriametrics:8428/api/v1/import
method: POST
headers:
  Content-Type: application/json
`,
			Permissions: 0644,
		},
		{
			Path: "traefik/crowdsec/var/log/auth.log",
			Content: "",
			Permissions: 0644,
		},
		{
			Path: "traefik/crowdsec/var/log/syslog",
			Content: "",
			Permissions: 0644,
		},
		// Traefik dynamic config
		{
			Path: "traefik/dynamic/core.yaml",
			Content: `# yaml-language-server: $schema=https://www.schemastore.org/traefik-v3-file-provider.json
http:
  routers:
    catchall:
      entryPoints:
        - web
        - websecure
      service: noop@internal
      rule: Host(` + "`$DOMAIN`" + `) || Host(` + "`$TS_HOSTNAME.$DOMAIN`" + `) || HostRegexp(` + "`^(.+)$`" + `)
      priority: 1
      middlewares:
        - traefikerrorreplace@file
  services:
    nginx-traefik-extensions:
      loadBalancer:
        servers:
          - url: http://nginx-traefik-extensions:80
  middlewares:
    traefikerrorreplace:
      plugin:
        traefikerrorreplace:
          matchStatus:
            - 418
          replaceStatus: 404
    nginx-auth:
      forwardAuth:
        address: http://nginx-traefik-extensions:80/auth
        trustForwardHeader: true
        authResponseHeaders: ["X-Auth-Method", "X-Auth-Passed", "X-Middleware-Name"]
    strip-www:
      redirectRegex:
        regex: '^(http|https)?://www\.(.+)$'
        replacement: '$1://$2'
        permanent: false
    crowdsec:
      plugin:
        bouncer:
          enabled: false
          logLevel: INFO
          crowdsecMode: live
          crowdsecLapiHost: crowdsec:8080
          crowdsecLapiScheme: http
          remediationStatusCode: 403
          forwardedHeadersTrustedIPs:
            - "127.0.0.1/32"
            - "10.0.0.0/8"
            - "172.16.0.0/12"
            - "192.168.0.0/16"
            - "::1/128"
          clientTrustedIPs:
            - "127.0.0.1/32"
            - "10.0.0.0/8"
            - "172.16.0.0/12"
            - "192.168.0.0/16"
            - "::1/128"
`,
			Permissions: 0644,
		},
		// Nginx traefik extensions
		{
			Path: "traefik/nginx-middlewares/nginx.conf",
			Content: `user nginx;
worker_processes auto;

error_log /dev/stderr warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '\n\r$time_iso8601 | $status | $remote_addr | $http_host | $request | ${request_time}ms | '
                    'auth_method="$auth_method" | $http_user_agent | '
                    'request_method=$request_method | '
                    'request_uri=$request_uri | '
                    'query_string=$query_string | '
                    'content_type=$content_type | '
                    'server_protocol=$server_protocol | '
                    'request_scheme=$scheme | '
                    '\n\rheaders: {'
                      '"accept":"$http_accept",'
                      '"accept_encoding":"$http_accept_encoding",'
                      '"cookie":"$http_cookie",'
                      '"x_forwarded_for":"$http_x_forwarded_for",'
                      '"x_forwarded_port":"$http_x_forwarded_port",'
                      '"x_forwarded_proto":"$http_x_forwarded_proto",'
                      '"x_forwarded_host":"$http_x_forwarded_host",'
                      '"x_real_ip":"$http_x_real_ip",'
                      '"x_api_key":"$http_x_api_key",'
                    '}';

    access_log /dev/stdout main;
    error_log /dev/stderr warn;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    map_hash_bucket_size 128;

    limit_req_zone $binary_remote_addr zone=auth:10m rate=10r/s;

    set_real_ip_from 10.0.6.0/24;
    set_real_ip_from 10.0.7.0/24;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    geo $ip_whitelisted {
        default 0;
        10.0.6.0/24 1;
        10.0.7.0/24 1;
    }

    map $http_x_api_key $api_key_valid {
        default 0;
    }

    upstream tinyauth {
        server auth:3000;
    }

    server {
        listen 80 default_server;
        server_name _;

        set $auth_passed 0;
        set $auth_method "none";

        if ($api_key_valid = 1) {
            set $auth_passed 1;
            set $auth_method "api_key";
        }

        if ($ip_whitelisted = 1) {
            set $auth_passed 1;
            set $auth_method "ip_whitelist";
        }

        location /auth {
            limit_req zone=auth burst=20 nodelay;
            if ($auth_passed = 1) {
                add_header X-Auth-Method "$auth_method" always;
                add_header X-Auth-Passed "true" always;
                return 200 "OK";
            }

            proxy_pass http://tinyauth/api/auth/traefik;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header X-Original-URI $http_x_original_uri;
            proxy_set_header X-Original-Method $http_x_original_method;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
            add_header X-Auth-Method "tinyauth" always;
            access_log /dev/stdout main;
        }

        location /health {
            access_log /dev/stdout main;
            return 200 "nginx service healthy\n";
            add_header Content-Type text/plain;
        }

        location / {
            access_log /dev/stdout main;
            return 200 "nginx service healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
`,
			Permissions: 0644,
		},
		// Zurg config (from src/zurg/docker-compose.yml - simple, no configs block)
		// Note: zurg uses volumes, not configs, so no default config file needed

		// ==========================================
		// Metrics configs from docker-compose.metrics.yml
		// ==========================================

		// Prometheus config
		{
			Path: "prometheus/prometheus.yml",
			Content: `global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'homelab'
    replica: 'prometheus'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:${ALERTMANAGER_PORT:-9093}

rule_files:
  - "alert.rules"

remote_write:
  - url: http://victoriametrics:${VICTORIAMETRICS_PORT:-8428}/api/v1/write
    queue_config:
      max_samples_per_send: 10000
      capacity: 20000
      max_shards: 30
    write_relabel_configs:
      - source_labels: [__name__]
        regex: 'go_.*'
        action: drop

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:${PROMETHEUS_PORT:-9090}']

  - job_name: 'victoriametrics'
    static_configs:
      - targets: ['victoriametrics:${VICTORIAMETRICS_PORT:-8428}']
    scrape_interval: 5s
    metrics_path: /metrics

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:${NODE_EXPORTER_PORT:-9100}']
    scrape_interval: 5s

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:${CADVISOR_PORT:-8080}']
    scrape_interval: 5s

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:${GRAFANA_PORT:-3000}']
    scrape_interval: 15s

  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8080']
    scrape_interval: 5s

  - job_name: 'crowdsec'
    static_configs:
      - targets: ['crowdsec:6060']
    scrape_interval: 15s

  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']
    scrape_interval: 15s

  - job_name: 'flaresolverr'
    static_configs:
      - targets: ['flaresolverr:${FLARESOLVERR_PORT:-9090}']
    scrape_interval: 15s
    metrics_path: /metrics

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:${REDIS_PORT:-6379}']
    scrape_interval: 15s

  - job_name: 'mongodb'
    static_configs:
      - targets: ['mongodb:${MONGODB_PORT:-27017}']
    scrape_interval: 30s

  - job_name: 'homepage'
    static_configs:
      - targets: ['homepage:${HOMEPAGE_PORT:-3000}']
    scrape_interval: 30s

  - job_name: 'portainer'
    static_configs:
      - targets: ['portainer:${PORTAINER_PORT:-9000}']
    scrape_interval: 30s

  - job_name: 'searxng'
    static_configs:
      - targets: ['searxng:${SEARXNG_PORT:-8080}']
    scrape_interval: 30s

  - job_name: 'code-server'
    static_configs:
      - targets: ['code-server:${CODE_SERVER_PORT:-8443}']
    scrape_interval: 30s

  - job_name: 'dozzle'
    static_configs:
      - targets: ['dozzle:${DOZZLE_PORT:-8080}']
    scrape_interval: 30s

  - job_name: 'bolabaden-nextjs'
    static_configs:
      - targets: ['bolabaden-nextjs:${BOLABADEN_NEXTJS_PORT:-3000}']
    scrape_interval: 30s

  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://grafana.$DOMAIN
        - https://victoriametrics.$DOMAIN
        - https://prometheus.$DOMAIN
        - https://traefik.$DOMAIN
        - https://crowdsec.$DOMAIN
        - https://flaresolverr.$DOMAIN
        - https://homepage.$DOMAIN
        - https://portainer.$DOMAIN
        - https://searxng.$DOMAIN
        - https://code-server.$DOMAIN
        - https://dozzle.$DOMAIN
        - https://$DOMAIN
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
`,
			Permissions: 0644,
		},
		// Additional metrics configs (alert.rules, loki, promtail, blackbox, grafana configs)
		// are loaded via ensureConfigFilesFromCompose() which reads from docker-compose.metrics.yml
		// This handles very large files like grafana.ini (2166 lines) and dashboard JSONs
	}
}

// ensureConfigFilesFromCompose extracts and creates configs from docker-compose files
// This is called after ensureConfigFiles() to handle configs defined in compose files
func ensureConfigFilesFromCompose(rootPath, configPath string) error {
	composeFiles := []string{
		filepath.Join(rootPath, "compose", "docker-compose.metrics.yml"),
		filepath.Join(rootPath, "compose", "docker-compose.coolify-proxy.yml"),
		filepath.Join(rootPath, "compose", "docker-compose.warp-nat-routing.yml"),
	}

	for _, composeFile := range composeFiles {
		if _, err := os.Stat(composeFile); os.IsNotExist(err) {
			continue
		}

		data, err := os.ReadFile(composeFile)
		if err != nil {
			continue
		}

		var compose map[string]interface{}
		if err := yaml.Unmarshal(data, &compose); err != nil {
			continue
		}

		configs, ok := compose["configs"].(map[string]interface{})
		if !ok {
			continue
		}

		// Map config names to target paths
		configPathMap := map[string]string{
			// Metrics configs
			"grafana.ini":                    "grafana/grafana.ini",
			"alert.rules":                    "prometheus/alert.rules",
			"loki.yaml":                      "loki/loki.yaml",
			"promtail.yaml":                  "promtail/promtail.yaml",
			"blackbox.yml":                   "blackbox-exporter/blackbox.yml",
			"grafana-datasource.yaml":        "grafana/provisioning/datasources/grafana-datasource.yaml",
			"grafana-dashboard.yaml":         "grafana/provisioning/dashboards/grafana-dashboard.yaml",
			"grafana-alerting.yaml":          "grafana/provisioning/alerting/grafana-alerting.yaml",
			"grafana-notifications.yaml":     "grafana/provisioning/notifiers/grafana-notifications.yaml",
			"grafana-plugins.yaml":           "grafana/provisioning/plugins/grafana-plugins.yaml",
			"node-exporter-dashboard.json":   "grafana/dashboards/system/node-exporter-dashboard.json",
			"cadvisor-dashboard.json":        "grafana/dashboards/infrastructure/cadvisor-dashboard.json",
			"blackbox-dashboard.json":        "grafana/dashboards/network/blackbox-dashboard.json",
			"traefik-dashboard.json":         "grafana/dashboards/infrastructure/traefik-dashboard.json",
			"crowdsec-dashboard.json":        "grafana/dashboards/infrastructure/crowdsec-dashboard.json",
			"flaresolverr-dashboard.json":    "grafana/dashboards/apps/flaresolverr-dashboard.json",
			"victoriametrics-dashboard.json": "grafana/dashboards/infrastructure/victoriametrics-dashboard.json",
			// WARP configs
			"warp-nat-setup.sh": "warp-nat-routing/warp-nat-setup.sh",
			"warp-monitor.sh":   "warp-nat-routing/warp-monitor.sh",
			// Coolify-proxy configs
			"traefik-dynamic.yaml":            "traefik/dynamic/core.yaml",
			"traefik-failover-dynamic.conf.tmpl": "traefik/dynamic/failover-fallbacks.yaml",
			"nginx-traefik-extensions.conf":   "traefik/nginx-middlewares/nginx.conf",
		}

		for name, cfg := range configs {
			cfgMap, ok := cfg.(map[string]interface{})
			if !ok {
				continue
			}

			var content string
			if c, ok := cfgMap["content"].(string); ok {
				content = c
			} else if file, ok := cfgMap["file"].(string); ok {
				// Config references a file - skip for now (would need to resolve path)
				continue
			} else {
				continue
			}

			// Map config name to target path
			targetPath, exists := configPathMap[name]
			if !exists {
				// Use name as path if no mapping exists
				targetPath = name
			}

			fullPath := filepath.Join(configPath, targetPath)

			// Skip if file already exists
			if _, err := os.Stat(fullPath); err == nil {
				continue
			}

			// Create directory
			dir := filepath.Dir(fullPath)
			if err := os.MkdirAll(dir, 0755); err != nil {
				return fmt.Errorf("failed to create directory %s: %w", dir, err)
			}

			// Determine permissions (default 0644, scripts 0700)
			perm := os.FileMode(0644)
			if filepath.Ext(fullPath) == ".sh" {
				perm = 0700
			}

			// Write file
			if err := os.WriteFile(fullPath, []byte(content), perm); err != nil {
				return fmt.Errorf("failed to write config file %s: %w", fullPath, err)
			}

			fmt.Printf("Created config from compose: %s\n", fullPath)
		}
	}

	return nil
}
