#!/bin/bash

# Coolify Deployment Script
# This script deploys a docker-compose stack to Coolify with environment variables

set -euo

# Configuration
COOLIFY_API_URL="https://app.coolify.io/api/v1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

Deploy a docker-compose stack to Coolify with environment variables.

Required Options:
  -t, --token TOKEN           Coolify API token
  -d, --docker-compose FILE   Path to docker-compose.yml file
  -e, --env-file FILE         Path to .env file
  -p, --project-uuid UUID     Project UUID in Coolify
  -s, --server-uuid UUID      Server UUID in Coolify

Optional Options:
  -n, --name NAME             Service name (default: extracted from docker-compose)
  --description DESC          Service description
  --environment-name NAME     Environment name (default: production)
  --destination-uuid UUID     Destination UUID (auto-detected if not provided)
  --instant-deploy            Deploy immediately after creation (default: false)
  --start-after-deploy        Start service after deployment (default: true)
  --api-url URL               Coolify API URL (default: https://app.coolify.io/api/v1)
  -h, --help                  Show this help message

Examples:
  $0 -t "your-api-token" -d docker-compose.yml -e .env -p "project-uuid" -s "server-uuid"
  $0 --token "token" --docker-compose stack.yml --env-file production.env --project-uuid "uuid" --server-uuid "uuid" --name "my-app"

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
            -d|--docker-compose)
                DOCKER_COMPOSE_FILE="$2"
                shift 2
                ;;
            -e|--env-file)
                ENV_FILE="$2"
                shift 2
                ;;
            -p|--project-uuid)
                PROJECT_UUID="$2"
                shift 2
                ;;
            -s|--server-uuid)
                SERVER_UUID="$2"
                shift 2
                ;;
            -n|--name)
                SERVICE_NAME="$2"
                shift 2
                ;;
            --description)
                SERVICE_DESCRIPTION="$2"
                shift 2
                ;;
            --environment-name)
                ENVIRONMENT_NAME="$2"
                shift 2
                ;;
            --destination-uuid)
                DESTINATION_UUID="$2"
                shift 2
                ;;
            --instant-deploy)
                INSTANT_DEPLOY="true"
                shift
                ;;
            --start-after-deploy)
                START_AFTER_DEPLOY="true"
                shift
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
    local errors=0
    
    if [[ -z "$API_TOKEN" ]]; then
        print_error "API token is required"
        errors=1
    else
        # Debug token format (without revealing the actual token)
        local token_length=${#API_TOKEN}
        local token_prefix="${API_TOKEN:0:3}"
        print_info "API token length: $token_length characters"
        print_info "API token prefix: $token_prefix..."
        
        # Check for common issues
        if [[ "$API_TOKEN" =~ [[:space:]] ]]; then
            print_warning "API token contains whitespace characters"
        fi
        
        if [[ "$API_TOKEN" =~ ^[0-9]+\| ]]; then
            print_info "Detected Laravel Sanctum token format"
        fi
    fi
    
    if [[ -z "$DOCKER_COMPOSE_FILE" ]]; then
        print_error "Docker compose file is required"
        errors=1
    fi
    
    if [[ -z "$ENV_FILE" ]]; then
        print_error "Environment file is required"
        errors=1
    fi
    
    if [[ -z "$PROJECT_UUID" ]]; then
        print_error "Project UUID is required"
        errors=1
    fi
    
    if [[ -z "$SERVER_UUID" ]]; then
        print_error "Server UUID is required"
        errors=1
    fi
    
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        print_error "Docker compose file not found: $DOCKER_COMPOSE_FILE"
        errors=1
    fi
    
    if [[ ! -f "$ENV_FILE" ]]; then
        print_error "Environment file not found: $ENV_FILE"
        errors=1
    fi
    
    if [[ $errors -gt 0 ]]; then
        exit 1
    fi
}

# Function to make API calls using temporary files
api_call() {
    local method="$1"
    local endpoint="$2"
    local data_file="$3"
    
    local url="${COOLIFY_API_URL}${endpoint}"
    
    # Debug: Print request details (remove token for security)
    print_info "Making $method request to: $url"
    if [[ -n "$data_file" && -f "$data_file" ]]; then
        print_info "Payload size: $(wc -c < "$data_file") bytes"
    fi
    
    # Common headers
    local auth_header="Authorization: Bearer $API_TOKEN"
    local content_header="Content-Type: application/json"
    local accept_header="Accept: application/json"
    
    if [[ "$method" == "GET" ]]; then
        curl -s -X GET \
            -H "$auth_header" \
            -H "$content_header" \
            -H "$accept_header" \
            "$url"
    else
        if [[ -n "$data_file" && -f "$data_file" ]]; then
            curl -s -X "$method" \
                -H "$auth_header" \
                -H "$content_header" \
                -H "$accept_header" \
                --data-binary "@$data_file" \
                "$url"
        else
            curl -s -X "$method" \
                -H "$auth_header" \
                -H "$content_header" \
                -H "$accept_header" \
                "$url"
        fi
    fi
}

# Function to test API token validity
test_api_token() {
    print_info "Testing API token validity..."
    
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
        print_success "API token is valid. Coolify version: $version"
        return 0
    fi
    
    print_warning "Unexpected response from version endpoint"
    cat "$response_file"
    return 1
}

# Function to parse environment variables from .env file using only file operations
parse_env_file() {
    local env_file="$1"
    local env_json_file="$TEMP_DIR/env_vars.json"
    
    print_info "Parsing environment file: $env_file ($(wc -c < "$env_file") bytes)"
    
    # Create temporary files for processing
    local temp_env_clean="$TEMP_DIR/env_clean.txt"
    local temp_env_processed="$TEMP_DIR/env_processed.txt"
    
    # Clean the env file - remove comments and empty lines
    grep -v '^[[:space:]]*#' "$env_file" | grep -v '^[[:space:]]*$' > "$temp_env_clean" || true
    
    # Count entries
    local count=$(wc -l < "$temp_env_clean")
    
    if [[ $count -eq 0 ]]; then
        print_warning "No environment variables found in $env_file"
        echo '[]' > "$env_json_file"
        echo "$env_json_file"
        return
    fi
    
    print_info "Found $count environment variables"
    
    # Process each line to create JSON objects
    echo '[' > "$env_json_file"
    
    local line_num=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Trim whitespace
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Remove quotes if present
            if [[ "$value" =~ ^[\"\'](.*)[\"\']$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            # Add comma if not first entry
            if [[ $line_num -gt 0 ]]; then
                echo ',' >> "$env_json_file"
            fi
            
            # Create individual temp files for key and value to avoid command line issues
            local temp_key="$TEMP_DIR/temp_key_$line_num"
            local temp_value="$TEMP_DIR/temp_value_$line_num"
            local temp_key_json="$TEMP_DIR/temp_key_json_$line_num"
            local temp_value_json="$TEMP_DIR/temp_value_json_$line_num"
            
            echo -n "$key" > "$temp_key"
            echo -n "$value" > "$temp_value"
            
            # Use jq to escape, reading from files
            jq -R . "$temp_key" > "$temp_key_json"
            jq -R . "$temp_value" > "$temp_value_json"
            
            # Build JSON object
            echo -n '  {' >> "$env_json_file"
            echo -n '"key": ' >> "$env_json_file"
            cat "$temp_key_json" >> "$env_json_file"
            echo -n ', "value": ' >> "$env_json_file"
            cat "$temp_value_json" >> "$env_json_file"
            echo -n ', "is_preview": false, "is_build_time": false, "is_literal": true, "is_multiline": false, "is_shown_once": false}' >> "$env_json_file"
            
            ((line_num++))
        fi
    done < "$temp_env_clean"
    
    echo '' >> "$env_json_file"
    echo ']' >> "$env_json_file"
    
    print_info "Environment JSON size: $(wc -c < "$env_json_file") bytes"
    echo "$env_json_file"
}

# Function to extract service name from docker-compose file
extract_service_name() {
    local compose_file="$1"
    
    # Use grep to find first service name without loading entire file into memory
    local service_name=$(grep -A 10 "^services:" "$compose_file" | grep -E "^  [a-zA-Z0-9_-]+:" | head -1 | sed 's/^  \([^:]*\):.*/\1/')
    
    if [[ -n "$service_name" ]]; then
        echo "$service_name"
    else
        echo "coolify-service"
    fi
}

# Function to create service using only file operations
create_service() {
    print_info "Creating service in Coolify..."
    
    local service_name="${SERVICE_NAME:-$(extract_service_name "$DOCKER_COMPOSE_FILE")}"
    local service_description="${SERVICE_DESCRIPTION:-"Deployed via API"}"
    local environment_name="${ENVIRONMENT_NAME:-production}"
    local instant_deploy="${INSTANT_DEPLOY:-false}"
    
    print_info "Docker compose file size: $(wc -c < "$DOCKER_COMPOSE_FILE") bytes"
    
    # Create temporary files for building JSON payload
    local temp_compose_json="$TEMP_DIR/compose_content.json"
    local temp_service_name="$TEMP_DIR/service_name.txt"
    local temp_description="$TEMP_DIR/description.txt"
    local temp_project_uuid="$TEMP_DIR/project_uuid.txt"
    local temp_env_name="$TEMP_DIR/env_name.txt"
    local temp_server_uuid="$TEMP_DIR/server_uuid.txt"
    
    # Write individual components to files
    echo -n "$service_name" > "$temp_service_name"
    echo -n "$service_description" > "$temp_description"
    echo -n "$PROJECT_UUID" > "$temp_project_uuid"
    echo -n "$environment_name" > "$temp_env_name"
    echo -n "$SERVER_UUID" > "$temp_server_uuid"
    
    # Convert docker-compose to JSON string using file input
    jq -Rs . "$DOCKER_COMPOSE_FILE" > "$temp_compose_json"
    
    # Build JSON payload using jq with file inputs
    local payload_file="$TEMP_DIR/service_payload.json"
    
    jq -n \
        --arg type "docker-compose" \
        --rawfile name "$temp_service_name" \
        --rawfile description "$temp_description" \
        --rawfile project_uuid "$temp_project_uuid" \
        --rawfile environment_name "$temp_env_name" \
        --rawfile server_uuid "$temp_server_uuid" \
        --argjson instant_deploy "$instant_deploy" \
        --rawfile docker_compose_raw "$temp_compose_json" \
        '{
            type: $type,
            name: $name,
            description: $description,
            project_uuid: $project_uuid,
            environment_name: $environment_name,
            server_uuid: $server_uuid,
            instant_deploy: $instant_deploy,
            docker_compose_raw: ($docker_compose_raw | fromjson)
        }' > "$payload_file"
    
    # Add destination UUID if provided
    if [[ -n "${DESTINATION_UUID:-}" ]]; then
        local temp_dest_uuid="$TEMP_DIR/dest_uuid.txt"
        echo -n "${DESTINATION_UUID:-}" > "$temp_dest_uuid"
        jq --rawfile destination_uuid "$temp_dest_uuid" '. + {destination_uuid: $destination_uuid}' "$payload_file" > "$payload_file.tmp"
        mv "$payload_file.tmp" "$payload_file"
    fi
    
    print_info "Service payload size: $(wc -c < "$payload_file") bytes"
    
    local response
    response=$(api_call "POST" "/services" "$payload_file")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create service"
        echo "$response"
        exit 1
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/service_response.json"
    echo "$response" > "$response_file"
    
    # Check if response contains an error
    if jq -e '.message' "$response_file" >/dev/null 2>&1; then
        local error_msg=$(jq -r '.message' "$response_file")
        if [[ "$error_msg" != "null" ]]; then
            print_error "Service creation failed: $error_msg"
            cat "$response_file"
            exit 1
        fi
    fi
    
    # Extract service UUID
    local service_uuid=$(jq -r '.uuid' "$response_file")
    
    if [[ "$service_uuid" == "null" || -z "$service_uuid" ]]; then
        print_error "Failed to extract service UUID from response"
        cat "$response_file"
        exit 1
    fi
    
    print_success "Service created successfully with UUID: $service_uuid"
    echo "$service_uuid"
}

# Function to update environment variables
update_env_vars() {
    local service_uuid="$1"
    local env_json_file="$2"
    
    # Check if env file is empty
    local env_count=$(jq length "$env_json_file")
    if [[ "$env_count" -eq 0 ]]; then
        print_info "No environment variables to update"
        return
    fi
    
    print_info "Updating $env_count environment variables..."
    
    # Create payload file for bulk env update
    local payload_file="$TEMP_DIR/env_payload.json"
    jq -n --rawfile data "$env_json_file" '{data: ($data | fromjson)}' > "$payload_file"
    
    print_info "Environment payload size: $(wc -c < "$payload_file") bytes"
    
    local response
    response=$(api_call "PATCH" "/services/$service_uuid/envs/bulk" "$payload_file")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to update environment variables"
        echo "$response"
        exit 1
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/env_response.json"
    echo "$response" > "$response_file"
    
    # Check if response contains success message
    if jq -e '.message' "$response_file" >/dev/null 2>&1; then
        local msg=$(jq -r '.message' "$response_file")
        if [[ "$msg" == "Environment variables updated." ]]; then
            print_success "Environment variables updated successfully"
        else
            print_error "Environment variables update failed: $msg"
            cat "$response_file"
            exit 1
        fi
    else
        print_success "Environment variables updated successfully"
    fi
}

# Function to start service
start_service() {
    local service_uuid="$1"
    
    print_info "Starting service..."
    
    local response
    response=$(api_call "GET" "/services/$service_uuid/start")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to start service"
        echo "$response"
        exit 1
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/start_response.json"
    echo "$response" > "$response_file"
    
    # Check if response contains success message
    if jq -e '.message' "$response_file" >/dev/null 2>&1; then
        local msg=$(jq -r '.message' "$response_file")
        print_success "Service start initiated: $msg"
    else
        print_success "Service start command sent"
    fi
}

# Function to check service status
check_service_status() {
    local service_uuid="$1"
    
    print_info "Checking service status..."
    
    local response
    response=$(api_call "GET" "/services/$service_uuid")
    
    if [[ $? -ne 0 ]]; then
        print_warning "Could not check service status"
        return
    fi
    
    # Save response to file for processing
    local response_file="$TEMP_DIR/status_response.json"
    echo "$response" > "$response_file"
    
    if jq -e '.name' "$response_file" >/dev/null 2>&1; then
        local name=$(jq -r '.name' "$response_file")
        print_info "Service '$name' is available in Coolify"
    fi
}

# Main function
main() {
    print_info "Starting Coolify deployment..."
    
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        exit 1
    fi
    
    # Test API token before proceeding
    if ! test_api_token; then
        print_error "API token validation failed. Cannot proceed with deployment."
        exit 1
    fi
    
    # Parse environment variables
    local env_json_file
    env_json_file=$(parse_env_file "$ENV_FILE")
    
    # Create service
    local service_uuid
    service_uuid=$(create_service)
    
    # Update environment variables
    update_env_vars "$service_uuid" "$env_json_file"
    
    # Start service if requested
    if [[ "${START_AFTER_DEPLOY:-true}" == "true" ]]; then
        start_service "$service_uuid"
    fi
    
    # Check status
    check_service_status "$service_uuid"
    
    print_success "Deployment completed successfully!"
    print_info "Service UUID: $service_uuid"
    print_info "You can monitor the deployment in the Coolify dashboard"
}

# Set defaults
ENVIRONMENT_NAME="production"
START_AFTER_DEPLOY="true"
INSTANT_DEPLOY="false"

# Parse arguments
parse_args "$@"

# Validate arguments
validate_args

# Run main function
main 