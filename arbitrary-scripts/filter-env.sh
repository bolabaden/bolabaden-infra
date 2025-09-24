#!/usr/bin/env bash
#
# filter-env.sh — filter .env file to only include variables
# actually referenced in a given folder (recursively).
# Preserves comments & blank lines.
#
# Usage:
#   ./filter-env.sh -e .env -d ./src -o .env.filtered [--example]
#

set -euo pipefail

show_help() {
  cat <<EOF
Usage: $0 -e ENV_FILE -d DIRECTORY -o OUTPUT_FILE [--example]

Options:
  -e  Path to the input .env file
  -d  Directory to scan for variable usage (recursively)
  -o  Path to write the filtered .env file
  --example  Generate an example .env (keep variable names, drop values)
  -h  Show this help message
EOF
}

# --- Parse arguments ---
ENV_FILE=""
SCAN_DIR=""
OUTPUT_FILE=""
EXAMPLE_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -e) ENV_FILE="$2"; shift 2 ;;
    -d) SCAN_DIR="$2"; shift 2 ;;
    -o) OUTPUT_FILE="$2"; shift 2 ;;
    --example) EXAMPLE_MODE=true; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
  esac
done

if [[ -z "$ENV_FILE" || -z "$SCAN_DIR" || -z "$OUTPUT_FILE" ]]; then
  echo "Error: Missing required arguments." >&2
  show_help
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env file not found: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -d "$SCAN_DIR" ]]; then
  echo "Error: Directory not found: $SCAN_DIR" >&2
  exit 1
fi

# --- Process .env file ---
> "$OUTPUT_FILE" # empty/create output file

while IFS= read -r line || [[ -n "$line" ]]; do
  # Keep comments and blank lines
  if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
    echo "$line" >> "$OUTPUT_FILE"
    continue
  fi

  # Extract variable name (before '=')
  var_name=$(echo "$line" | grep -oE '^[A-Za-z_][A-Za-z0-9_]*' || true)

  if [[ -n "$var_name" ]]; then
    if grep -Rqw "$var_name" "$SCAN_DIR"; then
      if $EXAMPLE_MODE; then
        # Keep key, strip value → VAR_NAME=
        echo "$var_name=" >> "$OUTPUT_FILE"
      else
        # Keep full line as-is
        echo "$line" >> "$OUTPUT_FILE"
      fi
    fi
  fi
done < "$ENV_FILE"

echo "Filtered .env written to $OUTPUT_FILE"
if $EXAMPLE_MODE; then
  echo "Example mode enabled — values stripped."
fi
