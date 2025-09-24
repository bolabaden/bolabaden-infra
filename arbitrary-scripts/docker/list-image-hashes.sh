#!/bin/bash

# Get the list of images with digests and sort them alphabetically
images=$(docker images --digests --format "{{.Repository}}:{{.Tag}}@{{.Digest}}" | sort)

# Print all images except those with <none> tag
echo "Docker Images (sorted alphabetically):"
echo "-------------------------------------"
while IFS= read -r image; do
  # Skip images with <none> tag
  if [[ "$image" != *"<none>"* ]]; then
    echo "$image"
  fi
done <<< "$images"