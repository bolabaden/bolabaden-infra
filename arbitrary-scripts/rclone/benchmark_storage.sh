#!/bin/bash

# benchmark_storage.sh
# A comprehensive storage benchmark script comparing rclone mounts with local storage
# Usage: ./benchmark_storage.sh <rclone_mount_path> <local_path>

# Set strict bash options
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print errors
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Check if required commands are installed
check_dependencies() {
    local missing_deps=()
    
    for cmd in dd fio rsync iozone; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo "Attempting to install missing dependencies automatically..."

        # Try to detect package manager and install
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            # Map iozone to iozone3 for apt
            to_install=()
            for dep in "${missing_deps[@]}"; do
                if [ "$dep" = "iozone" ]; then
                    to_install+=("iozone3")
                else
                    to_install+=("$dep")
                fi
            done
            sudo apt-get install -y "${to_install[@]}"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "${missing_deps[@]}"
        else
            print_error "Could not detect supported package manager (apt-get or yum)."
            echo "Please install missing dependencies manually: ${missing_deps[*]}"
            exit 1
        fi

        # Re-check if dependencies are now installed
        still_missing=()
        for cmd in "${missing_deps[@]}"; do
            if ! command -v "$cmd" &> /dev/null; then
                still_missing+=("$cmd")
            fi
        done

        if [ ${#still_missing[@]} -ne 0 ]; then
            print_error "Failed to install: ${still_missing[*]}"
            echo "Please install these dependencies manually."
            exit 1
        else
            print_success "All dependencies installed successfully."
        fi
    fi
}

# Function to run dd tests
run_dd_tests() {
    local path=$1
    local filename="$path/dd_testfile"
    
    print_header "Running DD Tests on $path"
    
    echo "Write speed test (1GB):"
    dd if=/dev/zero of="$filename" bs=1M count=1024 status=progress
    sync
    echo
    
    echo "Read speed test (1GB):"
    dd if="$filename" of=/dev/null bs=1M status=progress
    echo
    
    rm -f "$filename"
}

# Function to run fio tests
run_fio_tests() {
    local path=$1
    local filename="$path/fio_testfile"
    
    print_header "Running FIO Tests on $path"
    
    fio --name=test --filename="$filename" \
        --rw=readwrite --bs=4k --size=100M --direct=1 \
        --numjobs=1 --runtime=60 --group_reporting
    
    rm -f "$filename"
}

# Function to run rsync tests
run_rsync_tests() {
    local path=$1
    local source_dir="$path/source_test_dir"
    local dest_dir="$path/dest_test_dir"
    
    print_header "Running Rsync Tests on $path"
    
    # Create test directory with some files
    mkdir -p "$source_dir"
    for i in {1..10}; do
        dd if=/dev/urandom of="$source_dir/file$i" bs=1M count=10 2>/dev/null
    done
    
    echo "Copying 100MB of random files:"
    time rsync -av "$source_dir/" "$dest_dir/"
    
    # Cleanup
    rm -rf "$source_dir" "$dest_dir"
}

# Function to run iozone tests
run_iozone_tests() {
    local path=$1
    local filename="$path/iozone_testfile"
    
    print_header "Running IOzone Tests on $path"
    
    iozone -a -n 512M -g 1G -i 0 -i 1 -f "$filename"
    
    rm -f "$filename"
}

# Function to run small file operations test
run_small_files_test() {
    local path=$1
    local test_dir="$path/small_files_test"
    
    print_header "Running Small Files Test on $path"
    
    mkdir -p "$test_dir"
    
    echo "Creating 1000 small files:"
    time for i in {1..1000}; do
        touch "$test_dir/test_$i"
    done
    
    echo -e "\nDeleting 1000 small files:"
    time for i in {1..1000}; do
        rm "$test_dir/test_$i"
    done
    
    rmdir "$test_dir"
}

# Main function
main() {
    # Check arguments
    if [ $# -ne 2 ]; then
        print_error "Usage: $0 <rclone_mount_path> <local_path>"
        exit 1
    fi
    
    local rclone_path="$1"
    local local_path="$2"
    
    # Check if paths exist
    for path in "$rclone_path" "$local_path"; do
        if [ ! -d "$path" ]; then
            mkdir -p "$path"
        fi
        if [ ! -d "$path" ]; then
            print_error "Directory does not exist: $path"
            exit 1
        fi
        if [ ! -w "$path" ]; then
            print_error "Directory is not writable: $path"
            exit 1
        fi
    done
    
    # Check dependencies
    check_dependencies
    
    # Start benchmarking
    print_header "Starting Benchmark Suite"
    echo "Rclone Mount: $rclone_path"
    echo "Local Path: $local_path"
    
    # Run tests for both paths
    for path in "$rclone_path" "$local_path"; do
        print_header "Testing $path"
        
        run_dd_tests "$path"
        run_fio_tests "$path"
        run_rsync_tests "$path"
        run_iozone_tests "$path"
        run_small_files_test "$path"
    done
    
    print_success "Benchmark completed successfully!"
}

# Run main function with all arguments
main "$@"



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