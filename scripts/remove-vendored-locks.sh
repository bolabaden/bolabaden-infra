#!/bin/bash
#
# Remove package-lock.json files from vendored/reference code
# These files cause GitHub to report vulnerabilities for code we don't deploy or maintain
#

set -euo pipefail

echo "Removing package-lock.json files from vendored code..."

# Count before
BEFORE=$(find src/ vendor/ reference/ -name "package-lock.json" -type f 2>/dev/null | wc -l)
echo "Found $BEFORE package-lock.json files in vendored directories"

# Remove them
find src/ vendor/ reference/ -name "package-lock.json" -type f -delete 2>/dev/null || true

# Count after
AFTER=$(find src/ vendor/ reference/ -name "package-lock.json" -type f 2>/dev/null | wc -l)
echo "Removed $((BEFORE - AFTER)) files"
echo "Remaining: $AFTER"

echo ""
echo "These lock files are not needed because:"
echo "  1. The code is vendored/reference only"
echo "  2. We don't deploy these projects"
echo "  3. We don't maintain these dependencies"
echo ""
echo "The .gitattributes file already marks these directories as linguist-vendored."
echo "Removing lock files further reduces false-positive security warnings."

