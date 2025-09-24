#!/usr/bin/env bash

# Usage: ./get_image_tags.sh <image>
# Example: ./get_image_tags.sh ghcr.io/coanghel/rclone-docker-automount/rclone-init
#          ./get_image_tags.sh docker.io/11notes/traefik-labels
#          ./get_image_tags.sh nginx (partial name support)

set -euo pipefail
#set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR"

IMAGE="${1:-}"
PAGE_SIZE="${PAGE_SIZE:-${2:-1000}}"

if [[ -z "$IMAGE" ]]; then
  echo "Usage: $0 <image>"
  echo "Examples:"
  echo "  $0 nginx"
  echo "  $0 ghcr.io/coanghel/rclone-docker-automount/rclone-init"
  echo "  $0 docker.io/11notes/traefik-labels"
  exit 1
fi

# Resolve partial image names using docker image ls
resolve_partial_image() {
  local image="$1"

  # If image contains dots (registry domain), use it as-is
  if [[ "$image" =~ \. ]]; then
    echo "$image"
    return
  fi

  # Try to find the image in local docker images
  local matches
  matches=$(docker image ls --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -i "$image" | head -1000 || true)

  if [[ -z "$matches" ]]; then
    # No local matches found, assume it's a standard image and default to docker.io/library
    echo "library/$image"
    return
  fi

  # Count matches
  local count
  count=$(echo "$matches" | wc -l)

  if [[ $count -eq 1 ]]; then
    # Extract just the repository part (without tag)
    local repo_only
    repo_only=$(echo "$matches" | cut -d: -f1)
    echo "$repo_only"
  elif [[ $count -gt 1 ]]; then
    echo "Multiple matches found for '$image':" >&2
    echo "$matches" | nl -v 1 >&2
    local first_match
    first_match=$(echo "$matches" | head -1 | cut -d: -f1)
    echo "Using first match: $first_match" >&2
    echo "$first_match"
  else
    # Fallback to library/image
    echo "library/$image"
  fi
}

# Parse registry, namespace, and repo
parse_image() {
  local image="$1"
  local registry namespace repo

  # First resolve partial names
  image=$(resolve_partial_image "$image")

  # Remove tag if present (everything after colon)
  image="${image%%:*}"

  # Check for registry.domain format (contains dots)
  if [[ "$image" =~ ^([^.]+\.[^/]+)/([^/]+)/(.*)$ ]]; then
    # Full registry/namespace/repo format like ghcr.io/user/repo
    registry="${BASH_REMATCH[1]}"
    namespace="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"
  elif [[ "$image" =~ ^([^.]+\.[^/]+)/([^/]+)$ ]]; then
    # registry/namespace format like ghcr.io/user
    registry="${BASH_REMATCH[1]}"
    namespace="${BASH_REMATCH[2]}"
    repo=""
  elif [[ "$image" =~ ^([^/]+)/(.*)/(.*)$ ]]; then
    # Check if first part looks like a registry (common registry patterns or contains dots)
    local first_part="${BASH_REMATCH[1]}"
    if [[ "$first_part" =~ ^(docker\.io|ghcr\.io|quay\.io|registry\.k8s\.io|gcr\.io|k8s\.gcr\.io)$ ]] || [[ "$first_part" =~ \. ]]; then
      # It's a registry
      registry="$first_part"
      namespace="${BASH_REMATCH[2]}"
      repo="${BASH_REMATCH[3]}"
    else
      # Not a registry, this is likely namespace/repo format, default to docker.io
      registry="docker.io"
      namespace="$first_part"
      repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]}"
    fi
  elif [[ "$image" =~ ^([^/]+)/(.*)$ ]]; then
    # namespace/repo format
    registry="docker.io"
    namespace="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    # Just repo name
    registry="docker.io"
    namespace="library"
    repo="$image"
  fi
  echo "$registry" "$namespace" "$repo"
}

read -a PARSED_IMAGE <<< "$(parse_image "$IMAGE")"
REGISTRY="${PARSED_IMAGE[0]}"
NAMESPACE="${PARSED_IMAGE[1]}"
REPO="${PARSED_IMAGE[2]}"

echo "Fetching tags for image: $IMAGE ..."
ALL_TAGS=()
ALL_TAG_DATA=()

# Removed all individual tag API call functions to eliminate excessive API calls

# Find which tag "latest" points to from the API response directly
find_latest_tag() {
  # Simplified version that doesn't make additional API calls
  # For Docker Hub, we can check if any tag has the same digest as latest
  # For other registries, we'll skip this feature to avoid extra API calls
  echo ""
}

if [[ "$REGISTRY" == "docker.io" || "$REGISTRY" == "index.docker.io" ]]; then
  # Docker Hub - single API call to get tags with dates (no pagination)
  IMAGE_PATH="$NAMESPACE/$REPO"
  API_URL="https://registry.hub.docker.com/v2/repositories/$IMAGE_PATH/tags?page_size=$PAGE_SIZE"
  RESPONSE=$(curl -fsSL "$API_URL")
  TAGS=($(echo "$RESPONSE" | jq -r '.results[].name'))
  ALL_TAGS+=("${TAGS[@]}")

  # Extract dates directly from the response - no additional API calls
  for i in "${!TAGS[@]}"; do
    tag="${TAGS[$i]}"
    date=$(echo "$RESPONSE" | jq -r ".results[$i].last_updated // empty")
    if [[ -n "$date" && "$date" != "null" ]]; then
      # Convert to sortable format (ISO 8601)
      sortable_date=$(date -d "$date" -Iseconds 2>/dev/null || echo "$date")
      ALL_TAG_DATA+=("$sortable_date|$tag")
    else
      # If no date available, use a default old date
      ALL_TAG_DATA+=("1900-01-01T00:00:00Z|$tag")
    fi
  done
elif [[ "$REGISTRY" == "ghcr.io" ]]; then
  # GitHub Container Registry (public images; anonymous token required)
  # Perform the OCI Registry v2 token flow and then hit /tags/list with Bearer token.
  GHCR_PATH="$NAMESPACE/$REPO"

  # Build scope and URL-encode it for the token endpoint.
  # Scope format: repository:<path>:pull
  SCOPE_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('repository:${GHCR_PATH}:pull', safe=''))")
  TOKEN_URL="https://ghcr.io/token?service=ghcr.io&scope=${SCOPE_ENC}"

  TOKEN_JSON=$(curl -fsSL "$TOKEN_URL") || {
    echo "Failed to get anonymous token from GHCR token service."
    exit 1
  }
  TOKEN=$(echo "$TOKEN_JSON" | jq -r '.token') || {
    echo "Failed to parse token from GHCR response."
    exit 1
  }
  if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "Empty token from GHCR. The image may be private or access is restricted."
    exit 1
  fi

  # Single API call to get tags - no individual tag API calls
  NEXT_URL="https://ghcr.io/v2/${GHCR_PATH}/tags/list?n=${PAGE_SIZE}"
  while [[ -n "$NEXT_URL" ]]; do
    # Capture headers and body to parse both tags and pagination link.
    TMP_HEADERS=$(mktemp)
    RESPONSE=$(curl -fsSL -H "Authorization: Bearer ${TOKEN}" -D "$TMP_HEADERS" "$NEXT_URL") || {
      rm -f "$TMP_HEADERS"
      echo "Failed to fetch tags from GHCR. Check path: ${GHCR_PATH}"
      exit 1
    }

    # Extract tags
    TAGS=($(echo "$RESPONSE" | jq -r '.tags[]?' 2>/dev/null))
    if [[ ${#TAGS[@]} -gt 0 ]]; then
      ALL_TAGS+=("${TAGS[@]}")

      # GHCR doesn't provide dates in tag listing response, use default dates
      # No additional API calls for each tag
      for tag in "${TAGS[@]}"; do
        ALL_TAG_DATA+=("1900-01-01T00:00:00Z|$tag")
      done
    fi

    # Parse Link header for next page (may be relative like </v2/...>; rel="next")
    LINK_LINE=$(awk 'BEGIN{IGNORECASE=1} /^Link:/ {print; exit}' "$TMP_HEADERS")
    rm -f "$TMP_HEADERS"

    if [[ -z "$LINK_LINE" ]]; then
      NEXT_URL=""
    else
      # Extract URL inside <> that has rel="next"
      NEXT_RAW=$(echo "$LINK_LINE" | sed -n 's/.*<\([^>]*\)>\s*;\s*rel="?next"?.*/\1/p')
      if [[ -z "$NEXT_RAW" ]]; then
        NEXT_URL=""
      else
        if [[ "$NEXT_RAW" =~ ^/ ]]; then
          NEXT_URL="https://ghcr.io${NEXT_RAW}"
        else
          NEXT_URL="$NEXT_RAW"
        fi
      fi
    fi
  done


elif [[ "$REGISTRY" == "quay.io" ]]; then
  # Quay.io
  # Format: quay.io/namespace/repo
  NEXT_URL="https://quay.io/api/v1/repository/$NAMESPACE/$REPO/tag/?limit=$PAGE_SIZE"
  while [[ "$NEXT_URL" != "null" && -n "$NEXT_URL" ]]; do
    RESPONSE=$(curl -fsSL "$NEXT_URL")
    TAGS=($(echo "$RESPONSE" | jq -r '.tags[].name'))
    ALL_TAGS+=("${TAGS[@]}")

    # Extract dates from the Quay tag listing response
    for i in "${!TAGS[@]}"; do
      tag="${TAGS[$i]}"
      date=$(echo "$RESPONSE" | jq -r ".tags[$i].last_modified // empty")
      if [[ -n "$date" && "$date" != "null" ]]; then
        # Convert to sortable format (ISO 8601)
        sortable_date=$(date -d "$date" -Iseconds 2>/dev/null || echo "$date")
        ALL_TAG_DATA+=("$sortable_date|$tag")
      else
        # If no date available, use a default old date
        ALL_TAG_DATA+=("1900-01-01T00:00:00Z|$tag")
      fi
    done

    NEXT_URL=$(echo "$RESPONSE" | jq -r '.has_additional | select(.==true) | "https://quay.io/api/v1/repository/'"$NAMESPACE"'/'"$REPO"'/tag/?limit='"$PAGE_SIZE"'&page=" + (.page+1|tostring)')
    [[ -z "$NEXT_URL" ]] && break
  done
else
  echo "Registry '$REGISTRY' is not supported by this script."
  exit 2
fi

if [[ ${#ALL_TAGS[@]} -eq 0 ]]; then
  echo "No tags found or image does not exist."
  exit 1
fi

# Find which tag "latest" points to
LATEST_TAG=$(find_latest_tag "$REGISTRY" "$NAMESPACE" "$REPO" "${ALL_TAGS[@]}")

# Remove duplicates from tag data and sort by date (newest first)
SORTED_TAG_DATA=$(printf "%s\n" "${ALL_TAG_DATA[@]}" | sort -r | uniq)

echo -e "\nAvailable tags for '$IMAGE' (sorted by date, newest first):"
if [[ -n "$LATEST_TAG" ]]; then
  echo "Latest tag points to: $LATEST_TAG"
else
  echo "Could not determine what 'latest' tag points to"
fi
echo

# Display tags with dates
while IFS='|' read -r date tag; do
  if [[ "$tag" == "$LATEST_TAG" ]]; then
    # Format date for display (YYYY-MM-DD HH:MM)
    display_date=$(echo "$date" | sed 's/T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/T/' | sed 's/T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*Z$/T/' | sed 's/T/ /' | sed 's/Z$//' | cut -d'.' -f1)
    printf "%-20s %s (LATEST)\n" "$tag" "$display_date"
  else
    # Format date for display (YYYY-MM-DD HH:MM)
    display_date=$(echo "$date" | sed 's/T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/T/' | sed 's/T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*Z$/T/' | sed 's/T/ /' | sed 's/Z$//' | cut -d'.' -f1)
    printf "%-20s %s\n" "$tag" "$display_date"
  fi
done <<< "$SORTED_TAG_DATA"
