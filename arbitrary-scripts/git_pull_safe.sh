#!/bin/bash

# Git Pull Safe - Automatically handles merge conflicts with exclude-based resolution
# This script attempts a normal git pull first, and if conflicts arise,
# offers to resolve them by excluding problematic files from the merge

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository. Please run this script from a git repository."
        exit 1
    fi
}

# Function to get current branch
get_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

# Function to parse git pull/merge error output and extract conflicting files
parse_conflicting_files() {
    local output="$1"
    local conflicting_files=()
    
    # Extract file paths from the error output
    # Handle two patterns:
    # 1. "        filename" (indented with spaces) - from pull conflicts
    # 2. "CONFLICT (add/add): Merge conflict in filename" - from merge conflicts
    while IFS= read -r line; do
        # Pattern 1: Indented filenames from pull conflicts
        if [[ -n "$line" && "$line" =~ ^[[:space:]]+[^[:space:]] ]]; then
            local file_path=$(echo "$line" | sed 's/^[[:space:]]*//')
            if [[ -n "$file_path" ]]; then
                conflicting_files+=("$file_path")
            fi
        # Pattern 2: CONFLICT lines from merge conflicts
        elif [[ -n "$line" && "$line" =~ ^CONFLICT.*Merge[[:space:]]conflict[[:space:]]in[[:space:]](.+)$ ]]; then
            local file_path=$(echo "$line" | sed 's/^CONFLICT.*Merge conflict in //')
            if [[ -n "$file_path" ]]; then
                conflicting_files+=("$file_path")
            fi
        fi
    done <<< "$output"
    
    echo "${conflicting_files[@]}"
}

# Function to run the exclude-based solution
run_exclude_solution() {
    local pull_output="$1"
    local current_branch
    local conflicting_files
    current_branch=$(get_current_branch)
    conflicting_files=($(parse_conflicting_files "$pull_output"))
    
    print_status "Running exclude-based solution..."
    print_status "This will checkout files from origin/$current_branch while excluding problematic files"
    
    # Build the git checkout command with dynamic excludes
    local checkout_cmd="git checkout \"origin/$current_branch\" -- ."
    
    # Add exclude patterns for each conflicting file
    for file in "${conflicting_files[@]}"; do
        if [[ -n "$file" ]]; then
            checkout_cmd="$checkout_cmd ':(exclude)$file'"
        fi
    done
    
    print_status "Excluding the following files:"
    for file in "${conflicting_files[@]}"; do
        if [[ -n "$file" ]]; then
            echo "  - $file"
        fi
    done
    
    # Execute the checkout command
    if eval "$checkout_cmd"; then
        print_success "Successfully updated files from origin/$current_branch"
        print_status "Problematic files have been preserved locally"
        print_status "You can now commit your local changes or continue working"
    else
        print_error "Failed to run exclude-based solution"
        exit 1
    fi
}

# Function to ask user for confirmation
ask_confirmation() {
    local message="$1"
    local pull_output="$2"
    echo -e "${YELLOW}$message${NC}"
    echo -e "${BLUE}This will:${NC}"
    echo "  1. Fetch the latest changes from origin"
    echo "  2. Checkout updated files from origin/$(get_current_branch)"
    echo "  3. Exclude the following files from being overwritten:"
    
    # Parse and display the actual conflicting files
    local conflicting_files
    conflicting_files=($(parse_conflicting_files "$pull_output"))
    for file in "${conflicting_files[@]}"; do
        if [[ -n "$file" ]]; then
            echo "     - $file"
        fi
    done
    
    echo ""
    echo -e "${BLUE}This approach preserves your local changes to these files${NC}"
    echo ""
    echo -e "${BLUE}The command that will be executed:${NC}"
    echo -e "${YELLOW}git checkout \"origin/$(get_current_branch)\" -- . \\${NC}"
    
    # Show the exclude patterns
    for file in "${conflicting_files[@]}"; do
        if [[ -n "$file" ]]; then
            echo -e "${YELLOW}    ':(exclude)$file' \\${NC}"
        fi
    done
    echo ""
    
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    print_status "Git Pull Safe - Starting safe git pull process..."
    
    # Check if we're in a git repository
    check_git_repo
    
    # Get current branch
    local current_branch
    current_branch=$(get_current_branch)
    print_status "Current branch: $current_branch"
    
    # First, fetch the latest changes
    print_status "Fetching latest changes from origin..."
    if ! git fetch origin; then
        print_error "Failed to fetch from origin"
        exit 1
    fi
    
    # Attempt normal git pull
    print_status "Attempting normal git pull..."
    local pull_output
    if git pull 2>&1; then
        print_success "Git pull completed successfully!"
        exit 0
    else
        # Check if it's a diverging branches issue
        pull_output=$(git pull 2>&1 || true)
        
        if echo "$pull_output" | grep -q "Not possible to fast-forward"; then
            print_warning "Diverging branches detected. Attempting pull with --allow-unrelated-histories to identify conflicts..."
            
            # Try to pull with allow-unrelated-histories to get the actual conflict output
            if git pull --allow-unrelated-histories 2>&1; then
                print_success "Pull with --allow-unrelated-histories completed successfully!"
                exit 0
            else
                # Capture pull conflict output
                local pull_conflict_output
                pull_conflict_output=$(git pull --allow-unrelated-histories 2>&1 || true)
                
                # Check if we got pull conflicts
                if echo "$pull_conflict_output" | grep -q "CONFLICT\|Your local changes to the following files would be overwritten by merge"; then
                    print_warning "Pull conflicts detected during --allow-unrelated-histories attempt"
                    echo "$pull_conflict_output"
                    echo ""
                    
                    if ask_confirmation "Would you like to resolve this using the exclude-based approach?" "$pull_conflict_output"; then
                        run_exclude_solution "$pull_conflict_output"
                    else
                        print_status "Operation cancelled by user"
                        print_status "You can manually resolve conflicts or run this script again"
                        exit 0
                    fi
                else
                    # Different pull error
                    print_error "Pull with --allow-unrelated-histories failed with an unexpected error:"
                    echo "$pull_conflict_output"
                    print_status "Please resolve the issue manually"
                    exit 1
                fi
            fi
        elif echo "$pull_output" | grep -q "Your local changes to the following files would be overwritten by merge"; then
            print_warning "Merge conflicts detected with local changes"
            echo "$pull_output"
            echo ""
            
            if ask_confirmation "Would you like to resolve this using the exclude-based approach?" "$pull_output"; then
                run_exclude_solution "$pull_output"
            else
                print_status "Operation cancelled by user"
                print_status "You can manually resolve conflicts or run this script again"
                exit 0
            fi
        else
            # Different error occurred
            print_error "Git pull failed with an unexpected error:"
            echo "$pull_output"
            print_status "This script only handles specific merge conflicts with local changes"
            print_status "Please resolve the issue manually"
            exit 1
        fi
    fi
}

# Run the main function
main "$@"
