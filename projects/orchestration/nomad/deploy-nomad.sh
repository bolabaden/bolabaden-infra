#!/bin/bash

# Media Stack Nomad Deployment Script
# This script helps deploy and manage the converted Docker Compose media stack on Nomad

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NOMAD_JOBS=(
    "nomad-variables.hcl"
    "nomad-media-stack.hcl"
    "nomad-storage-management.hcl"
    "nomad-media-core-services.hcl"
    "nomad-web-services.hcl"
    "nomad-vpn-services.hcl"
    "nomad-ai-services.hcl"
    "nomad-media-services.hcl"
    "nomad-additional-services.hcl"
    "nomad-stremio-addons.hcl"
    "nomad-servarr-services.hcl"
    "nomad-utility-debrid-services.hcl"
    "nomad-dashboard-services.hcl"
)

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

# Function to check if Nomad is available
check_nomad() {
    if ! command -v nomad &> /dev/null; then
        print_error "Nomad CLI not found. Please install Nomad first."
        exit 1
    fi
    
    if ! nomad status &> /dev/null; then
        print_error "Cannot connect to Nomad cluster. Please check your Nomad configuration."
        exit 1
    fi
    
    print_success "Nomad CLI is available and connected"
}

# Function to validate job files
validate_jobs() {
    print_status "Validating Nomad job files..."
    
    for job_file in "${NOMAD_JOBS[@]}"; do
        if [[ ! -f "$job_file" ]]; then
            print_error "Job file not found: $job_file"
            exit 1
        fi
        
        print_status "Validating $job_file..."
        if nomad job validate "$job_file"; then
            print_success "$job_file is valid"
        else
            print_error "$job_file validation failed"
            exit 1
        fi
    done
}

# Function to deploy jobs
deploy_jobs() {
    print_status "Deploying Nomad jobs..."
    
    for job_file in "${NOMAD_JOBS[@]}"; do
        print_status "Deploying $job_file..."
        
        if nomad job run "$job_file"; then
            print_success "$job_file deployed successfully"
        else
            print_error "Failed to deploy $job_file"
            exit 1
        fi
        
        # Wait a bit between deployments to avoid overwhelming the cluster
        sleep 5
    done
}

# Function to check job status
check_status() {
    print_status "Checking job status..."
    
    echo -e "\n${BLUE}Job Status Summary:${NC}"
    nomad job status
    
    echo -e "\n${BLUE}Detailed Status:${NC}"
    for job_file in "${NOMAD_JOBS[@]}"; do
        job_name=$(grep -E "^job " "$job_file" | head -1 | sed 's/job "\([^"]*\)".*/\1/')
        if [[ -n "$job_name" ]]; then
            echo -e "\n${YELLOW}=== $job_name ===${NC}"
            nomad job status "$job_name" || print_warning "Job $job_name not found"
        fi
    done
}

# Function to stop all jobs
stop_jobs() {
    print_status "Stopping all media stack jobs..."
    
    for job_file in "${NOMAD_JOBS[@]}"; do
        job_name=$(grep -E "^job " "$job_file" | head -1 | sed 's/job "\([^"]*\)".*/\1/')
        if [[ -n "$job_name" ]]; then
            print_status "Stopping $job_name..."
            if nomad job stop "$job_name" 2>/dev/null; then
                print_success "$job_name stopped"
            else
                print_warning "$job_name was not running or already stopped"
            fi
        fi
    done
}

# Function to purge all jobs
purge_jobs() {
    print_status "Purging all media stack jobs..."
    
    for job_file in "${NOMAD_JOBS[@]}"; do
        job_name=$(grep -E "^job " "$job_file" | head -1 | sed 's/job "\([^"]*\)".*/\1/')
        if [[ -n "$job_name" ]]; then
            print_status "Purging $job_name..."
            if nomad job stop -purge "$job_name" 2>/dev/null; then
                print_success "$job_name purged"
            else
                print_warning "$job_name was not found or already purged"
            fi
        fi
    done
}

# Function to show logs
show_logs() {
    local job_name="$1"
    local task_name="$2"
    
    if [[ -z "$job_name" ]]; then
        print_error "Please specify a job name"
        echo "Available jobs:"
        for job_file in "${NOMAD_JOBS[@]}"; do
            job=$(grep -E "^job " "$job_file" | head -1 | sed 's/job "\([^"]*\)".*/\1/')
            echo "  - $job"
        done
        return 1
    fi
    
    if [[ -z "$task_name" ]]; then
        print_status "Showing logs for job: $job_name (all tasks)"
        nomad alloc logs -job "$job_name"
    else
        print_status "Showing logs for job: $job_name, task: $task_name"
        nomad alloc logs -job "$job_name" -task "$task_name"
    fi
}

# Function to restart a specific job
restart_job() {
    local job_name="$1"
    
    if [[ -z "$job_name" ]]; then
        print_error "Please specify a job name"
        return 1
    fi
    
    print_status "Restarting job: $job_name"
    
    # Find the corresponding job file
    local job_file=""
    for file in "${NOMAD_JOBS[@]}"; do
        if grep -q "job \"$job_name\"" "$file"; then
            job_file="$file"
            break
        fi
    done
    
    if [[ -z "$job_file" ]]; then
        print_error "Job file not found for job: $job_name"
        return 1
    fi
    
    # Stop and redeploy
    nomad job stop "$job_name" || true
    sleep 5
    nomad job run "$job_file"
    print_success "Job $job_name restarted"
}

# Function to show help
show_help() {
    echo "Media Stack Nomad Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  validate    Validate all job files"
    echo "  deploy      Deploy all jobs to Nomad"
    echo "  status      Check status of all jobs"
    echo "  stop        Stop all jobs"
    echo "  purge       Stop and purge all jobs"
    echo "  restart     Restart a specific job"
    echo "  logs        Show logs for a job"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy                           # Deploy all jobs"
    echo "  $0 status                           # Check all job statuses"
    echo "  $0 restart media-stack-core         # Restart core services"
    echo "  $0 logs media-stack-web-services    # Show logs for web services"
    echo "  $0 logs media-stack-core mongodb    # Show logs for specific task"
    echo ""
    echo "Job Files:"
    for job_file in "${NOMAD_JOBS[@]}"; do
        echo "  - $job_file"
    done
}

# Main script logic
main() {
    local command="$1"
    shift || true
    
    case "$command" in
        "validate")
            check_nomad
            validate_jobs
            ;;
        "deploy")
            check_nomad
            validate_jobs
            deploy_jobs
            print_success "All jobs deployed successfully!"
            ;;
        "status")
            check_nomad
            check_status
            ;;
        "stop")
            check_nomad
            stop_jobs
            print_success "All jobs stopped"
            ;;
        "purge")
            check_nomad
            purge_jobs
            print_success "All jobs purged"
            ;;
        "restart")
            check_nomad
            restart_job "$1"
            ;;
        "logs")
            check_nomad
            show_logs "$1" "$2"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
