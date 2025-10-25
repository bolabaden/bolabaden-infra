#!/bin/bash
# Cleanup broken symlinks

echo "Cleaning up broken symlinks..."

# Find and remove broken symlinks in media directories
find /mnt/media -type l -exec test ! -e {} \; -print -delete
find /mnt/symlinks -type l -exec test ! -e {} \; -print -delete

echo "Symlink cleanup complete"