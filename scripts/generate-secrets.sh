#!/usr/bin/env bash
################################################################################
# Docker Secrets Generator
# 
# This script reads a .secrets file and generates individual secret files
# for use with Docker Compose secrets functionality.
#
# Usage:
#   ./generate-secrets.sh [options]
#
# Options:
#   -s, --secrets-file FILE    Path to .secrets file (default: ../secrets)
#   -o, --output-dir DIR       Output directory for secret files (default: ../secrets)
#   -f, --force                Overwrite existing secret files
#   -v, --verbose              Enable verbose output
#   -h, --help                 Show this help message
#
# Example:
#   ./generate-secrets.sh -s ../.secrets -o ../secrets -f
#
################################################################################

set -euo pipefail

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="${REPO_ROOT}/.secrets"
OUTPUT_DIR="${REPO_ROOT}/secrets"
FORCE=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to print verbose messages
verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$BLUE" "[VERBOSE] $*"
    fi
}

# Function to print error messages
error() {
    print_color "$RED" "[ERROR] $*" >&2
}

# Function to print warning messages
warning() {
    print_color "$YELLOW" "[WARNING] $*"
}

# Function to print success messages
success() {
    print_color "$GREEN" "[SUCCESS] $*"
}

# Function to print info messages
info() {
    print_color "$BLUE" "[INFO] $*"
}

# Function to show usage
usage() {
    cat << EOF
Docker Secrets Generator

Usage: $0 [options]

Options:
    -s, --secrets-file FILE    Path to .secrets file (default: ${SECRETS_FILE})
    -o, --output-dir DIR       Output directory for secret files (default: ${OUTPUT_DIR})
    -f, --force                Overwrite existing secret files
    -v, --verbose              Enable verbose output
    -h, --help                 Show this help message

Examples:
    # Generate secrets with default settings
    $0

    # Specify custom paths
    $0 -s /path/to/.secrets -o /path/to/secrets

    # Force overwrite existing files with verbose output
    $0 -f -v

EOF
    exit 0
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--secrets-file)
                SECRETS_FILE="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Function to validate inputs
validate_inputs() {
    if [[ ! -f "$SECRETS_FILE" ]]; then
        error "Secrets file not found: $SECRETS_FILE"
        error "Please create it based on .secrets.example"
        exit 1
    fi

    verbose "Using secrets file: $SECRETS_FILE"
    verbose "Output directory: $OUTPUT_DIR"
}

# Function to create output directory
create_output_dir() {
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        verbose "Creating output directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
    fi
}

# Function to convert variable name to filename
# Example: SUDO_PASSWORD -> sudo-password.txt
var_to_filename() {
    local var_name="$1"
    echo "${var_name,,}" | tr '_' '-'
}

# Function to generate secret files
generate_secrets() {
    local count=0
    local skipped=0
    local created=0

    info "Processing secrets from: $SECRETS_FILE"
    
    # Read the secrets file line by line
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip empty lines and comments
        if [[ -z "$key" ]] || [[ "$key" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Trim whitespace from key
        key=$(echo "$key" | xargs)
        
        # Skip if key is empty after trimming
        if [[ -z "$key" ]]; then
            continue
        fi

        # Remove quotes from value if present
        value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

        # Generate filename
        filename="${OUTPUT_DIR}/$(var_to_filename "$key").txt"
        
        count=$((count + 1))

        # Check if file exists and force is not enabled
        if [[ -f "$filename" ]] && [[ "$FORCE" != "true" ]]; then
            verbose "Skipping existing file: $filename"
            skipped=$((skipped + 1))
            continue
        fi

        # Write secret to file
        echo -n "$value" > "$filename"
        chmod 600 "$filename"
        verbose "Created: $filename"
        created=$((created + 1))

    done < "$SECRETS_FILE"

    echo
    success "✓ Secrets generation complete!"
    info "Total secrets processed: $count"
    info "Secrets created: $created"
    if [[ $skipped -gt 0 ]]; then
        info "Secrets skipped (already exist): $skipped"
        info "Use --force to overwrite existing files"
    fi
}

# Function to set proper permissions
set_permissions() {
    info "Setting proper permissions on secrets directory..."
    chmod 700 "$OUTPUT_DIR"
    find "$OUTPUT_DIR" -type f -name "*.txt" -exec chmod 600 {} \;
    success "✓ Permissions set"
}

# Function to verify secret files
verify_secrets() {
    local empty_count=0
    
    info "Verifying generated secret files..."
    
    while IFS= read -r -d '' file; do
        if [[ ! -s "$file" ]]; then
            warning "Empty secret file: $file"
            empty_count=$((empty_count + 1))
        fi
    done < <(find "$OUTPUT_DIR" -type f -name "*.txt" -print0)
    
    if [[ $empty_count -eq 0 ]]; then
        success "✓ All secret files verified"
    else
        warning "Found $empty_count empty secret file(s)"
        warning "Please check your .secrets file for missing values"
    fi
}

# Function to show summary
show_summary() {
    echo
    info "========================================"
    info "Secrets Location: $OUTPUT_DIR"
    info "========================================"
    echo
    info "Next steps:"
    echo "  1. Review the generated secret files in: $OUTPUT_DIR"
    echo "  2. Ensure .secrets and secrets/ are in .gitignore"
    echo "  3. Start your Docker Compose services"
    echo
    warning "⚠️  IMPORTANT: Never commit secret files to version control!"
    echo
}

# Main execution
main() {
    parse_args "$@"
    
    info "Docker Secrets Generator"
    info "========================"
    echo
    
    validate_inputs
    create_output_dir
    generate_secrets
    set_permissions
    verify_secrets
    show_summary
}

# Run main function
main "$@"

