#!/usr/bin/env bash
################################################################################
# Docker Secrets Verification Script
#
# Verifies that all required secrets exist and are properly configured
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="${REPO_ROOT}/secrets"
SECRETS_FILE="${REPO_ROOT}/.secrets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if .secrets file exists
check_secrets_file() {
    print_header "Checking .secrets File"
    
    if [[ -f "$SECRETS_FILE" ]]; then
        print_success ".secrets file exists"
        
        # Check permissions
        perms=$(stat -c "%a" "$SECRETS_FILE")
        if [[ "$perms" == "600" ]]; then
            print_success "Permissions correct (600)"
        else
            print_warning "Permissions are $perms (should be 600)"
            echo "  Fix with: chmod 600 $SECRETS_FILE"
        fi
        
        # Check for placeholder values
        if grep -q "REPLACE_ME\|your_\|generate_" "$SECRETS_FILE" 2>/dev/null; then
            print_warning "Found placeholder values in .secrets"
            echo "  Please replace all placeholder values with actual secrets"
        else
            print_success "No obvious placeholders found"
        fi
    else
        print_error ".secrets file not found"
        echo "  Create it from template: cp .secrets.example .secrets"
        return 1
    fi
}

# Check if secrets directory exists
check_secrets_dir() {
    print_header "Checking Secrets Directory"
    
    if [[ -d "$SECRETS_DIR" ]]; then
        print_success "Secrets directory exists"
        
        # Check permissions
        perms=$(stat -c "%a" "$SECRETS_DIR")
        if [[ "$perms" == "700" ]]; then
            print_success "Directory permissions correct (700)"
        else
            print_warning "Directory permissions are $perms (should be 700)"
            echo "  Fix with: chmod 700 $SECRETS_DIR"
        fi
        
        # Count files
        count=$(find "$SECRETS_DIR" -name "*.txt" -type f | wc -l)
        print_info "Found $count secret files"
    else
        print_error "Secrets directory not found"
        echo "  Run: ./scripts/generate-secrets.sh"
        return 1
    fi
}

# Check individual secret files
check_secret_files() {
    print_header "Checking Secret Files"
    
    local total=0
    local valid=0
    local empty=0
    local bad_perms=0
    
    while IFS= read -r -d '' file; do
        total=$((total + 1))
        filename=$(basename "$file")
        
        # Check if file is empty
        if [[ ! -s "$file" ]]; then
            print_error "$filename is empty"
            empty=$((empty + 1))
            continue
        fi
        
        # Check permissions
        perms=$(stat -c "%a" "$file")
        if [[ "$perms" != "600" ]]; then
            print_warning "$filename has permissions $perms (should be 600)"
            bad_perms=$((bad_perms + 1))
        else
            valid=$((valid + 1))
        fi
    done < <(find "$SECRETS_DIR" -name "*.txt" -type f -print0 2>/dev/null)
    
    echo
    print_info "Total: $total | Valid: $valid | Empty: $empty | Bad Permissions: $bad_perms"
    
    if [[ $empty -gt 0 ]]; then
        print_warning "Fix empty files by updating .secrets and regenerating"
    fi
    
    if [[ $bad_perms -gt 0 ]]; then
        print_warning "Fix permissions with: chmod 600 secrets/*.txt"
    fi
    
    if [[ $valid -eq $total ]]; then
        print_success "All secret files are valid!"
    fi
}

# Check critical secrets
check_critical_secrets() {
    print_header "Checking Critical Secrets"
    
    local critical_secrets=(
        "sudo-password"
        "authentik-secret-key"
        "grafana-secret-key"
        "openai-api-key"
        "litellm-master-key"
    )
    
    local missing=0
    
    for secret in "${critical_secrets[@]}"; do
        file="$SECRETS_DIR/${secret}.txt"
        if [[ -f "$file" ]] && [[ -s "$file" ]]; then
            print_success "$secret exists"
        else
            print_error "$secret missing or empty"
            missing=$((missing + 1))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        echo
        print_success "All critical secrets present!"
    else
        echo
        print_error "$missing critical secret(s) missing"
        echo "  Run: ./scripts/generate-secrets.sh -f"
    fi
}

# Check SECRETS_PATH in .env
check_env_config() {
    print_header "Checking Environment Configuration"
    
    if [[ -f "$REPO_ROOT/.env" ]]; then
        if grep -q "^SECRETS_PATH=" "$REPO_ROOT/.env"; then
            secrets_path=$(grep "^SECRETS_PATH=" "$REPO_ROOT/.env" | cut -d= -f2- | tr -d '"')
            print_success "SECRETS_PATH is set: $secrets_path"
        else
            print_error "SECRETS_PATH not set in .env"
            echo "  Add: SECRETS_PATH=\"$SECRETS_DIR\""
        fi
        
        if grep -q "^SECRETS_DIR=" "$REPO_ROOT/.env"; then
            print_success "SECRETS_DIR is set"
        else
            print_warning "SECRETS_DIR not set (optional)"
        fi
    else
        print_error ".env file not found"
    fi
}

# Check gitignore
check_gitignore() {
    print_header "Checking .gitignore"
    
    if [[ -f "$REPO_ROOT/.gitignore" ]]; then
        if grep -q "^\.secrets$" "$REPO_ROOT/.gitignore"; then
            print_success ".secrets is gitignored"
        else
            print_error ".secrets NOT in .gitignore"
            echo "  Add: echo '.secrets' >> .gitignore"
        fi
        
        if grep -q "^secrets/$" "$REPO_ROOT/.gitignore"; then
            print_success "secrets/ is gitignored"
        elif grep -q "^secrets/$" "$REPO_ROOT/.gitignore"; then
            print_success "secrets/ is gitignored (as 'secrets/')"
        else
            print_warning "secrets/ directory should be in .gitignore"
        fi
    else
        print_warning ".gitignore not found"
    fi
}

# Main verification
main() {
    print_header "Docker Secrets Verification"
    echo
    
    check_secrets_file
    echo
    check_secrets_dir
    echo
    check_secret_files
    echo
    check_critical_secrets
    echo
    check_env_config
    echo
    check_gitignore
    echo
    
    print_header "Verification Complete"
    echo
    print_info "Next steps:"
    echo "  1. Fix any errors or warnings above"
    echo "  2. Run: ./scripts/generate-secrets.sh -f (if needed)"
    echo "  3. Start services: docker compose up -d"
    echo
}

main "$@"

