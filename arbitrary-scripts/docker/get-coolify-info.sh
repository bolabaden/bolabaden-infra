#!/bin/bash

# Coolify Info Helper Script
# This script helps you get the required UUIDs for deployment

set -e

# Configuration
COOLIFY_API_URL="https://app.coolify.io/api/v1"

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

Get project and server UUIDs from your Coolify instance.

Required Options:
  -t, --token TOKEN           Coolify API token

Optional Options:
  --api-url URL               Coolify API URL (default: https://app.coolify.io/api/v1)
  -h, --help                  Show this help message

Examples:
  $0 -t "your-api-token"
  $0 --token "token" --api-url "https://your-coolify.domain.com/api/v1"

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
            -n|--name)
                SERVICE_NAME="$2"
                shift 2
                ;;
            -d|--description)
                SERVICE_DESCRIPTION="$2"
                shift 2
                ;;
            -p|--project)
                PROJECT_UUID="$2"
                shift 2
                ;;
            -s|--server)
                SERVER_UUID="$2"
                shift 2
                ;;
            -e|--env)
                ENV_FILE="$2"
                shift 2
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
    if [[ -z "$API_TOKEN" ]]; then
        print_error "API token is required"
        exit 1
    fi
}

# Function to make API calls
api_call() {
    local method="$1"
    local endpoint="$2"
    
    local url="${COOLIFY_API_URL}${endpoint}"
    
    curl -s -X "$method" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        "$url"
}

# Function to get version info
get_version() {
    print_info "Getting Coolify version..."
    
    local response
    response=$(api_call "GET" "/version")
    
    if [[ $? -eq 0 ]]; then
        local version=$(echo "$response" | jq -r '.' 2>/dev/null)
        if [[ "$version" != "null" && -n "$version" ]]; then
            print_success "Coolify version: $version"
        else
            print_warning "Could not determine Coolify version"
        fi
    else
        print_warning "Could not connect to Coolify API"
    fi
}

# Function to list projects
list_projects() {
    print_info "Fetching projects..."
    
    local response
    response=$(api_call "GET" "/projects")
    
    if [[ $? -eq 0 ]]; then
        if echo "$response" | jq -e '.[]' >/dev/null 2>&1; then
            echo ""
            echo "Available Projects:"
            echo "=================="
            echo "$response" | jq -r '.[] | "Name: \(.name)\nUUID: \(.uuid)\nDescription: \(.description // "No description")\n---"' 2>/dev/null || {
                print_warning "Could not parse projects response"
                echo "$response"
            }
        else
            print_warning "No projects found or unable to parse response"
        fi
    else
        print_error "Failed to fetch projects"
    fi
}

# Function to list servers
list_servers() {
    print_info "Fetching servers..."
    
    local response
    response=$(api_call "GET" "/servers")
    
    if [[ $? -eq 0 ]]; then
        if echo "$response" | jq -e '.[]' >/dev/null 2>&1; then
            echo ""
            echo "Available Servers:"
            echo "=================="
            echo "$response" | jq -r '.[] | "Name: \(.name)\nUUID: \(.uuid)\nIP: \(.ip)\nDescription: \(.description // "No description")\n---"' 2>/dev/null || {
                print_warning "Could not parse servers response"
                echo "$response"
            }
        else
            print_warning "No servers found or unable to parse response"
        fi
    else
        print_error "Failed to fetch servers"
    fi
}

# Function to list services
list_services() {
    print_info "Fetching existing services..."
    
    local response
    response=$(api_call "GET" "/services")
    
    if [[ $? -eq 0 ]]; then
        if echo "$response" | jq -e '.[]' >/dev/null 2>&1; then
            echo ""
            echo "Existing Services:"
            echo "=================="
            echo "$response" | jq -r '.[] | "Name: \(.name)\nUUID: \(.uuid)\nType: \(.service_type // "Unknown")\nDescription: \(.description // "No description")\n---"' 2>/dev/null || {
                print_warning "Could not parse services response"
                echo "$response"
            }
        else
            print_info "No services found"
        fi
    else
        print_error "Failed to fetch services"
    fi
}

# Function to generate deployment command
generate_deployment_command() {
    echo ""
    echo "Deployment Command Template:"
    echo "============================"
    echo ""
    echo "$0 \\"
    echo "  -t \"YOUR_API_TOKEN\" \\"
    echo "  -d \"docker-compose.yml\" \\"
    echo "  -e \".env\" \\"
    echo "  -p \"PROJECT_UUID_FROM_ABOVE\" \\"
    echo "  -s \"SERVER_UUID_FROM_ABOVE\" \\"
    echo "  -n \"my-service-name\" \\"
    echo "  --description \"My service description\""
    echo ""
    echo "Replace the UUIDs with the actual values from the lists above."
}

# Main function
main() {
    print_info "Fetching Coolify information..."
    
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        exit 1
    fi
    
    # Get version info
    get_version
    
    # List all the information
    list_projects
    list_servers
    list_services
    
    # Generate deployment command template
    generate_deployment_command
    
    print_success "Information retrieval completed!"
}

# Parse arguments
parse_args "$@"

# Validate arguments
validate_args

# Run main function
main 