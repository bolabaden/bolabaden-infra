#!/bin/sh

# Configurable variables (can be overridden via env or command line)
TRAEFIK_LOG_DIR="${TRAEFIK_LOG_DIR:-${1:-/var/log/traefik}}"
TRAEFIK_LOG_FILENAME="${TRAEFIK_LOG_FILENAME:-traefik.log}"
LOG_LEVEL="${LOG_LEVEL:-info}"  # debug, info, warning, error
LOGROTATE_LOOP_SLEEP="${LOGROTATE_LOOP_SLEEP:-300}"  # seconds
LOGROTATE_MAXSIZE="${LOGROTATE_MAXSIZE:-10M}"
LOGROTATE_MAXCOUNT="${LOGROTATE_MAXCOUNT:-20}"
LOGROTATE_ROTATE_FREQ="${LOGROTATE_ROTATE_FREQ:-hourly}"
LOGROTATE_MAXDIR_MB="${LOGROTATE_MAXDIR_MB:-50}"  # Max total log dir size in MB before gz cleanup
LOGROTATE_KEEP_GZ="${LOGROTATE_KEEP_GZ:-10}"      # How many gzipped logs to keep
LOGROTATE_STATE_FILE="${LOGROTATE_STATE_FILE:-/var/lib/logrotate.status}"
STATUS_CODES="${STATUS_CODES:-100-999}"           # Comma-separated, e.g. 100,200,300-350,400-500,900

# Helper: log if LOG_LEVEL is debug/verbose
log_debug() {
  case "$LOG_LEVEL" in
    debug|verbose) echo "$@";;
  esac
}
log_info() {
  case "$LOG_LEVEL" in
    debug|verbose|info) echo "$@";;
  esac
}
log_warn() {
  case "$LOG_LEVEL" in
    debug|verbose|info|warning) echo "$@";;
  esac
}
log_error() {
  echo "$@" >&2
}

apk add --no-cache logrotate findutils coreutils jq &&
mkdir -p /etc/logrotate.d &&
cat > /etc/logrotate.d/traefik << EOF
  $TRAEFIK_LOG_DIR/*.log {
    $LOGROTATE_ROTATE_FREQ
    size $LOGROTATE_MAXSIZE
    rotate $LOGROTATE_MAXCOUNT
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    copytruncate
    postrotate
        echo "[POSTROTATE] Checking for old gzipped logs..."
        TOTAL_SIZE=\$(du -sm \$TRAEFIK_LOG_DIR | cut -f1)
        echo "[POSTROTATE] Directory size: \$TOTAL_SIZE MB"
        if [ "\$TOTAL_SIZE" -gt "$LOGROTATE_MAXDIR_MB" ]; then
            echo "[POSTROTATE] Cleaning up old gz logs beyond $LOGROTATE_KEEP_GZ most recent"
            find \$TRAEFIK_LOG_DIR -name "*.gz" -type f | sort | head -n -$LOGROTATE_KEEP_GZ | xargs -r rm -f
        fi
    endscript
}
EOF

mkdir -p /var/lib

# Force an initial logrotate run to ensure config is valid and logrotate is working
log_info "[INIT] $(date -u '+%Y-%m-%dT%H:%M:%SZ') Forcing initial rotation of traefik logs..."
if ! logrotate -s "$LOGROTATE_STATE_FILE" -v /etc/logrotate.d/traefik 2>&1 | sed 's/^/[INIT] /'; then
  log_error "[INIT] ERROR: initial logrotate failed at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fi

# Start logrotate in background (monitor + rotate)
(
  while true; do
    if [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "verbose" ]; then
      log_debug "[LOGROTATE LOOP] Sleeping ${LOGROTATE_LOOP_SLEEP}s..."
    fi
    sleep "$LOGROTATE_LOOP_SLEEP"

    if [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "verbose" ]; then
      log_debug "[LOGROTATE LOOP] Checking state file..."
      if [ -f "$LOGROTATE_STATE_FILE" ]; then
        sed 's/^/[STATE] /' "$LOGROTATE_STATE_FILE"
      else
        log_debug "[STATE] No $LOGROTATE_STATE_FILE file found."
      fi
    fi

    if [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "verbose" ]; then
      log_debug "[LOGROTATE LOOP] $(date -u +%FT%TZ) Running verbose rotation..."
      logrotate -s "$LOGROTATE_STATE_FILE" -v /etc/logrotate.d/traefik 2>&1 | sed 's/^/[VERBOSE] /'
      log_debug "[LOGROTATE LOOP] Checking log dir sizes..."
      du -sh "$TRAEFIK_LOG_DIR" 2>&1 | sed 's/^/[SIZE] /'
      ls -lh "$TRAEFIK_LOG_DIR" 2>&1 | sed 's/^/[FILES] /'
    else
      log_info "[LOGROTATE LOOP] $(date -u +%FT%TZ) Running rotation..."
      logrotate -s "$LOGROTATE_STATE_FILE" /etc/logrotate.d/traefik 2>&1 | sed 's/^/[VERBOSE] /'
    fi
  done
) &

# Wait for log file to exist, then tail it
log_info "Waiting for $TRAEFIK_LOG_FILENAME to be created..."
while [ ! -f "$TRAEFIK_LOG_DIR/$TRAEFIK_LOG_FILENAME" ]; do
  sleep 5
done

log_info "Starting to tail $TRAEFIK_LOG_FILENAME in human-readable format..."

# Helper: parse STATUS_CODES into a grep-able regex
parse_status_codes() {
  local codes="$1"
  local regex=""
  local IFS=,
  for part in $codes; do
    if echo "$part" | grep -q -- '-'; then
      # Range
      start=$(echo "$part" | cut -d- -f1)
      end=$(echo "$part" | cut -d- -f2)
      regex="${regex:+$regex|}($(seq $start $end | tr '\n' '|' | sed 's/|$//'))"
    else
      regex="${regex:+$regex|}($part)"
    fi
  done
  # Remove duplicate pipes, wrap in ^ and $
  regex="^(${regex})$"
  echo "$regex"
}

STATUS_CODE_REGEX=$(parse_status_codes "$STATUS_CODES")

# Use tail -F to follow across rotations, stdbuf for line buffering, jq for JSON parsing
stdbuf -oL -eL tail -n 200 -F "$TRAEFIK_LOG_DIR/$TRAEFIK_LOG_FILENAME" | \
while read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    '{'*)
      # Parse log line and output fields separated by tabs
      parsed_line=$(
        echo "$line" | jq -r '
          def ms: ( . // 0 | tonumber) / 1000000 | floor;
          [
            (.time // "?"),
            ((.DownstreamStatus // 0) | tostring),
            (.ClientAddr // "?"),
            (.RequestHost // "?"),
            ((.RequestMethod // "?") + " " + (.RequestPath // "?")),
            ((.Duration | ms | tostring) + " ms"),
            (.ServiceName // "?")
          ] | @tsv
        '
      )

      # Extract client IP address (3rd field) and resolve to domain name if possible
      client_addr=$(echo "$parsed_line" | awk -F"\t" '{print $3}')
      client_ip=$(echo "$client_addr" | sed 's/:[0-9]*$//')
      resolved_addr=$(nslookup "$client_ip" 2>/dev/null | awk '/name =/ {print $4; exit}' | sed 's/\.$//')
      if [ -z "$resolved_addr" ] || [ "$resolved_addr" = "$client_ip" ]; then
        resolved_addr="$client_addr"
      else
        port_part=$(echo "$client_addr" | grep -o ':[0-9]*$')
        resolved_addr="$resolved_addr$port_part"
      fi

      parsed_line=$(echo "$parsed_line" | awk -F"\t" -v new_addr="$resolved_addr" 'BEGIN{OFS="\t"} {$3=new_addr; print}')

      status_code=$(echo "$parsed_line" | awk -F"\t" '{print $2}')
      # Only print if status_code matches filter
      if echo "$status_code" | grep -Eq "$STATUS_CODE_REGEX"; then
        # Assign unique colors for common/relevant codes, and dynamically for others
        case "$status_code" in
          200) color="\033[1;32m" ;;   # Bright Green
          201) color="\033[0;32m" ;;   # Green
          204) color="\033[0;36m" ;;   # Cyan
          301) color="\033[1;34m" ;;   # Bright Blue
          302) color="\033[0;34m" ;;   # Blue
          304) color="\033[1;36m" ;;   # Bright Cyan
          400) color="\033[1;33m" ;;   # Bright Yellow
          401) color="\033[0;33m" ;;   # Yellow
          403) color="\033[1;35m" ;;   # Bright Magenta
          404) color="\033[0;35m" ;;   # Magenta
          408) color="\033[1;31m" ;;   # Bright Red
          429) color="\033[0;31m" ;;   # Red
          500) color="\033[1;91m" ;;   # Bright Red (alt)
          502) color="\033[1;95m" ;;   # Bright Magenta (alt)
          503) color="\033[1;94m" ;;   # Bright Blue (alt)
          504) color="\033[1;93m" ;;   # Bright Yellow (alt)
          *)
            palette="31 32 33 34 35 36 91 92 93 94 95 96"
            code_num=$(echo "$status_code" | grep -Eo '[0-9]+' || echo 0)
            set -- $palette
            palette_len=12
            idx=$(($code_num % $palette_len))
            color_code=$(echo $palette | awk -v n=$((idx+1)) '{split($0,a," "); print a[n]}')
            color="\033[1;${color_code}m"
            ;;
        esac
        # Print the line with only the timestamp and status code colored
        echo "$parsed_line" | awk -F"\t" -v color="$color" -v reset="\033[0m" '
          {
            printf "%s%-19s%s | %s%-3s%s | %-18s | %-25s | %-21s | %-8s | %s\n", \
              color, $1, reset, color, $2, reset, $3, $4, $5, $6, $7;
          }
        '
      fi
      ;;
    *)
      ;;
  esac
done