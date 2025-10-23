#!/bin/bash

# Coolify Helper Script
# This script helps you get the required UUIDs and test API connectivity

set -euo pipefail

# Configuration
COOLIFY_API_URL="https://app.coolify.io/api/v1"
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
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

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Helper script to get Coolify project and server UUIDs and test API connectivity.

Required Options:
  -t, --token TOKEN           Coolify API token

Optional Options:
  --api-url URL               Coolify API URL (default: https://app.coolify.io/api/v1)
  -h, --help                  Show this help message

Examples:
  $0 -t "your-api-token"
  $0 --token "3|WaobqX9tJQshKPuQFHsyApxuOOggg4wOfvGc9xa233c376d7"

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--token)
                API_TOKEN="$2"
                shift 2
                ;;
            --api-url)
                COOLIFY_API_URL="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate required arguments
validate_args() {
    if [[ -z "${API_TOKEN:-}" ]]; then
        print_error "API token is required"
        exit 1
    fi
}

# Function to make API calls
api_call() {
    local method="$1"
    local endpoint="$2"
    
    local url="${COOLIFY_API_URL}${endpoint}"
    
    print_info "Making $method request to: $url"
    
    curl -s -X "$method" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "$url"
}

# Function to test API connectivity
test_api() {
    print_info "Testing API connectivity..."
    
    local response
    response=$(api_call "GET" "/version")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to connect to Coolify API"
        return 1
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/version_response.json"
    echo "$response" > "$response_file"
    
    # Check if we got an authentication error
    if jq -e '.message' "$response_file" >/dev/null 2>&1; then
        local msg=$(jq -r '.message' "$response_file")
        if [[ "$msg" == "Unauthenticated." ]]; then
            print_error "API token is invalid or expired"
            print_error "Please check your token and permissions"
            return 1
        fi
    fi
    
    # Check if we got a version response (indicating success)
    if jq -e 'type == "string"' "$response_file" >/dev/null 2>&1; then
        local version=$(jq -r '.' "$response_file")
        print_success "API connection successful. Coolify version: $version"
        return 0
    fi
    
    print_warning "Unexpected response from version endpoint"
    cat "$response_file"
    return 1
}

# Function to list projects
list_projects() {
    print_info "Fetching projects..."
    
    local response
    response=$(api_call "GET" "/projects")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to fetch projects"
        return 1
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/projects_response.json"
    echo "$response" > "$response_file"
    
    # Check if we got an error
    if jq -e '.message' "$response_file" >/dev/null 2>&1; then
        local msg=$(jq -r '.message' "$response_file")
        print_error "Failed to fetch projects: $msg"
        return 1
    fi
    
    # Check if we got an array of projects
    if jq -e 'type == "array"' "$response_file" >/dev/null 2>&1; then
        local project_count=$(jq length "$response_file")
        print_success "Found $project_count projects:"
        
        # Display projects in a table format
        echo ""
        printf "%-40s %-20s %-15s\n" "UUID" "NAME" "DESCRIPTION"
        printf "%-40s %-20s %-15s\n" "----" "----" "-----------"
        
        jq -r '.[] | [.uuid, .name, .description] | @tsv' "$response_file" | while IFS=$'\t' read -r uuid name description; do
            printf "%-40s %-20s %-15s\n" "$uuid" "$name" "$description"
        done
        
        return 0
    fi
    
    print_warning "Unexpected response format"
    cat "$response_file"
    return 1
}

# Function to list servers
list_servers() {
    print_info "Fetching servers..."
    
    local response
    response=$(api_call "GET" "/servers")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to fetch servers"
        return 1
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/servers_response.json"
    echo "$response" > "$response_file"
    
    # Check if we got an error
    if jq -e '.message' "$response_file" >/dev/null 2>&1; then
        local msg=$(jq -r '.message' "$response_file")
        print_error "Failed to fetch servers: $msg"
        return 1
    fi
    
    # Check if we got an array of servers
    if jq -e 'type == "array"' "$response_file" >/dev/null 2>&1; then
        local server_count=$(jq length "$response_file")
        print_success "Found $server_count servers:"
        
        # Display servers in a table format
        echo ""
        printf "%-40s %-20s %-15s %-10s\n" "UUID" "NAME" "IP" "STATUS"
        printf "%-40s %-20s %-15s %-10s\n" "----" "----" "--" "------"
        
        jq -r '.[] | [.uuid, .name, .ip, .status] | @tsv' "$response_file" | while IFS=$'\t' read -r uuid name ip status; do
            printf "%-40s %-20s %-15s %-10s\n" "$uuid" "$name" "$ip" "$status"
        done
        
        return 0
    fi
    
    print_warning "Unexpected response format"
    cat "$response_file"
    return 1
}

# Function to list services
list_services() {
    print_info "Fetching services..."
    
    local response
    response=$(api_call "GET" "/services")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to fetch services"
        return 1
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/services_response.json"
    echo "$response" > "$response_file"
    
    # Check if we got an error
    if jq -e '.message' "$response_file" >/dev/null 2>&1; then
        local msg=$(jq -r '.message' "$response_file")
        print_error "Failed to fetch services: $msg"
        return 1
    fi
    
    # Check if we got an array of services
    if jq -e 'type == "array"' "$response_file" >/dev/null 2>&1; then
        local service_count=$(jq length "$response_file")
        print_success "Found $service_count services:"
        
        # Display services in a table format
        echo ""
        printf "%-40s %-20s %-15s\n" "UUID" "NAME" "DESCRIPTION"
        printf "%-40s %-20s %-15s\n" "----" "----" "-----------"
        
        jq -r '.[] | [.uuid, .name, .description] | @tsv' "$response_file" | while IFS=$'\t' read -r uuid name description; do
            printf "%-40s %-20s %-15s\n" "$uuid" "$name" "$description"
        done
        
        return 0
    fi
    
    print_warning "Unexpected response format"
    cat "$response_file"
    return 1
}

# Main function
main() {
    print_info "Coolify Helper - Getting UUIDs and testing connectivity..."
    
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        exit 1
    fi
    
    # Test API connectivity first
    if ! test_api; then
        print_error "API connectivity test failed. Cannot proceed."
        exit 1
    fi
    
    echo ""
    print_info "=== PROJECTS ==="
    list_projects
    
    echo ""
    print_info "=== SERVERS ==="
    list_servers
    
    echo ""
    print_info "=== EXISTING SERVICES ==="
    list_services
    
    echo ""
    print_success "Helper script completed successfully!"
    print_info "Use the UUIDs above with the deploy-coolify.sh script:"
    print_info "  ./deploy-coolify.sh -t \"your-token\" -p \"project-uuid\" -s \"server-uuid\" -d docker-compose.yml -e .env"
}

# Parse arguments
parse_args "$@"

# Validate arguments
validate_args

# Run main function
main 