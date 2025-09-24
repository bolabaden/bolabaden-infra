#!/bin/bash

# Check if a path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-folder>"
    exit 1
fi

MOUNT_POINT="$1"

# Check if the path exists and is a directory
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Error: $MOUNT_POINT is not a valid directory"
    exit 1
fi

# Check if fio is installed
if ! command -v fio &> /dev/null; then
    echo "Error: fio is not installed. Please install it first."
    echo "On Ubuntu/Debian: sudo apt-get install fio"
    echo "On CentOS/RHEL: sudo yum install fio"
    exit 1
fi

# Create a temporary file for testing
TEST_FILE="$MOUNT_POINT/benchmark_test_file"
TEMP_DIR=$(mktemp -d)

echo "Starting filesystem benchmark for: $MOUNT_POINT"
echo "----------------------------------------"

# Get filesystem information
echo "Filesystem Information:"
df -h "$MOUNT_POINT" | grep -v "tmpfs\|devtmpfs"
echo "----------------------------------------"

# Sequential Write Test
echo "Sequential Write Test (1GB):"
dd if=/dev/zero of="$TEST_FILE" bs=1G count=1 oflag=direct status=progress 2>&1 | grep -v "records"
echo "----------------------------------------"

# Sequential Read Test
echo "Sequential Read Test:"
dd if="$TEST_FILE" of=/dev/null bs=1G count=1 iflag=direct status=progress 2>&1 | grep -v "records"
echo "----------------------------------------"

# Random I/O Test using fio
echo "Random I/O Test (4KB blocks, mixed read/write):"
fio --name=random_test \
    --directory="$MOUNT_POINT" \
    --rw=randrw \
    --bs=4k \
    --direct=1 \
    --numjobs=4 \
    --time_based \
    --runtime=30 \
    --size=1G \
    --group_reporting \
    --output-format=normal \
    --output="$TEMP_DIR/fio_results.txt"

# Display fio results
cat "$TEMP_DIR/fio_results.txt"
echo "----------------------------------------"

# Cleanup
rm -f "$TEST_FILE"
rm -rf "$TEMP_DIR"

echo "Benchmark completed!" 