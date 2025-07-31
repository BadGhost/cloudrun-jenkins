#!/bin/bash

# Ultra-Frugal Jenkins Deployment Script for Google Cloud Platform
# Following Google Cloud Terraform Best Practices
#
# This script automates the deployment of a cost-optimized Jenkins environment 
# on GCP using Terraform. It follows Google Cloud Terraform best practices with
# environment separation and module-based architecture.
#
# Usage:
#   ./deploy.sh [dev|prod] [--skip-validation] [--force] [--destroy]
#
# Examples:
#   ./deploy.sh                    # Deploy to development environment
#   ./deploy.sh prod               # Deploy to production environment  
#   ./deploy.sh dev --force        # Deploy without confirmation prompts
#   ./deploy.sh dev --destroy      # Destroy the development environment
#
# Requirements:
#   - Bash 4.0+
#   - Google Cloud SDK (gcloud)
#   - Terraform 1.0+
#   - Proper GCP project with billing enabled
#
# Project Structure:
#   cloudrun-jenkins/
#   ├── modules/ultra-frugal-jenkins/    # Reusable Jenkins module
#   ├── environments/
#   │   ├── dev/                         # Development environment
#   │   └── prod/                        # Production environment
#   └── deploy.sh                        # This deployment script

set -euo pipefail

# Default values
ENVIRONMENT="dev"
SKIP_VALIDATION=false
FORCE=false
DESTROY=false

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_PATH="modules/ultra-frugal-jenkins"
ENVIRONMENT_PATH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_header() {
    echo ""
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    echo ""
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info() {
    echo -e "${WHITE}[INFO]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Ultra-Frugal Jenkins Deployment Script

USAGE:
    ./deploy.sh [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    dev     Deploy to development environment (default)
    prod    Deploy to production environment

OPTIONS:
    --skip-validation    Skip prerequisite validation checks
    --force             Apply changes without confirmation prompts
    --destroy           Destroy infrastructure instead of creating it
    --help              Show this help message

EXAMPLES:
    ./deploy.sh                           # Deploy to dev with all validations
    ./deploy.sh prod --force              # Deploy to prod without prompts
    ./deploy.sh dev --destroy             # Destroy dev environment
    ./deploy.sh dev --skip-validation     # Deploy to dev, skip validation

REQUIREMENTS:
    - Bash 4.0+
    - Google Cloud SDK (gcloud) installed and authenticated
    - Terraform 1.0+ installed
    - GCP project with billing enabled
    - Configuration file: environments/ENVIRONMENT/terraform.tfvars

For detailed setup instructions, see: QUICK_START.md

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            dev|prod)
                ENVIRONMENT="$1"
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --destroy)
                DESTROY=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done
    
    ENVIRONMENT_PATH="environments/$ENVIRONMENT"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate project structure
validate_project_structure() {
    log_step "Validating project structure..."
    
    local required_paths=(
        "$MODULE_PATH"
        "$MODULE_PATH/main.tf"
        "$MODULE_PATH/variables.tf"
        "$MODULE_PATH/outputs.tf"
        "$MODULE_PATH/versions.tf"
        "$ENVIRONMENT_PATH"
        "$ENVIRONMENT_PATH/main.tf"
        "$ENVIRONMENT_PATH/variables.tf"
        "$ENVIRONMENT_PATH/outputs.tf"
        "$ENVIRONMENT_PATH/versions.tf"
        "$ENVIRONMENT_PATH/backend.tf"
    )
    
    local missing_paths=()
    for path in "${required_paths[@]}"; do
        if [[ ! -e "$path" ]]; then
            missing_paths+=("$path")
        fi
    done
    
    if [[ ${#missing_paths[@]} -gt 0 ]]; then
        log_error "Project structure validation failed. Missing required files:"
        for path in "${missing_paths[@]}"; do
            echo -e "  ${RED}✗${NC} $path"
        done
        echo ""
        log_error "Invalid project structure. Ensure you have the correct Google Cloud Terraform structure."
        exit 1
    fi
    
    log_success "Project structure validation passed"
}

# Function to validate prerequisites
validate_prerequisites() {
    log_step "Validating prerequisites..."
    
    local errors=()
    
    # Check Bash version
    if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
        errors+=("Bash 4.0 or later is required. Current version: $BASH_VERSION")
    fi
    
    # Check if gcloud is installed and authenticated
    if ! command_exists gcloud; then
        errors+=("Google Cloud SDK (gcloud) is not installed or not in PATH")
    else
        local gcloud_auth
        if ! gcloud_auth=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null); then
            errors+=("Unable to check Google Cloud authentication status")
        elif [[ -z "$gcloud_auth" ]]; then
            errors+=("No active Google Cloud authentication found. Run 'gcloud auth login'")
        else
            log_success "Authenticated as: $gcloud_auth"
        fi
    fi
    
    # Check if terraform is installed
    if ! command_exists terraform; then
        errors+=("Terraform is not installed or not in PATH")
    else
        local terraform_version
        # Try JSON format first, fallback to parsing text output
        if terraform_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null) && [[ -n "$terraform_version" && "$terraform_version" != "null" ]]; then
            log_success "Terraform version: $terraform_version"
        elif terraform_version=$(terraform version 2>/dev/null | head -n1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)*' | head -n1); then
            # Remove 'v' prefix if present
            terraform_version="${terraform_version#v}"
            log_success "Terraform version: $terraform_version"
        else
            errors+=("Unable to determine Terraform version")
        fi
        
        # Check if version is 1.0 or later (only if we successfully got the version)
        if [[ -n "$terraform_version" && "$terraform_version" != "null" ]]; then
            local major_version="${terraform_version%%.*}"
            if [[ $major_version -lt 1 ]]; then
                errors+=("Terraform 1.0 or later is required. Current version: $terraform_version")
            fi
        fi
    fi
    
    # Validate project structure
    validate_project_structure
    
    # Check if terraform.tfvars exists in environment
    local tfvars_path="$ENVIRONMENT_PATH/terraform.tfvars"
    if [[ ! -f "$tfvars_path" ]]; then
        errors+=("Configuration file not found: $tfvars_path")
        errors+=("Copy from $ENVIRONMENT_PATH/terraform.tfvars.example and customize.")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_header "❌ Prerequisite Check Failed"
        for error in "${errors[@]}"; do
            log_error "$error"
        done
        echo ""
        log_warning "Please fix the above issues and try again."
        echo ""
        echo -e "${CYAN}Quick setup guide:${NC}"
        echo "1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
        echo "2. Install Terraform: https://terraform.io/downloads"
        echo "3. Authenticate: gcloud auth login"
        echo "4. Configure environment:"
        echo "   cd $ENVIRONMENT_PATH"
        echo "   cp terraform.tfvars.example terraform.tfvars"
        echo "   # Edit terraform.tfvars with your settings"
        echo ""
        echo -e "${BLUE}For detailed setup, see: QUICK_START.md${NC}"
        exit 1
    fi
    
    log_success "All prerequisites validated!"
}

# Function to validate GCP project access
validate_project_access() {
    local project_id="$1"
    
    log_step "Validating project access: $project_id"
    
    if gcloud projects describe "$project_id" --format="value(projectId)" >/dev/null 2>&1; then
        log_success "Project access validated: $project_id"
        return 0
    else
        log_error "Cannot access project: $project_id"
        return 1
    fi
}

# Function to show cost estimate
show_cost_estimate() {
    log_header "💰 Estimated Monthly Costs"
    
    echo -e "${CYAN}Ultra-Frugal Jenkins on GCP - Cost Breakdown:${NC}"
    echo ""
    
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        cat << 'EOF'
Environment: PRODUCTION

┌─────────────────────────────┬─────────────┬─────────────────────────────────┐
│ Component                   │ Monthly USD │ Notes                           │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ Cloud Run Controller        │ $0.10-0.30  │ Higher traffic expected         │
│ Spot VM Agents (2-4 x e2)   │ $0.30-0.80  │ 91% discount, auto-scaling      │
│ Cloud Storage (25GB)        │ $0.10-0.25  │ More builds & artifacts         │
│ Load Balancer (IAP)         │ $0.20-0.30  │ HTTPS + Identity-Aware Proxy    │
│ Networking (VPC, etc.)      │ $0.10-0.20  │ Private networking              │
│ Monitoring & Logging        │ $0.05-0.15  │ Enhanced production monitoring  │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ TOTAL ESTIMATED             │ $0.85-2.00  │ At upper limit of budget        │
└─────────────────────────────┴─────────────┴─────────────────────────────────┘
EOF
    else
        cat << 'EOF'
Environment: DEVELOPMENT

┌─────────────────────────────┬─────────────┬─────────────────────────────────┐
│ Component                   │ Monthly USD │ Notes                           │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ Cloud Run Controller        │ $0.00-0.20  │ Scales to zero when idle        │
│ Spot VM Agents (1-2 x e2)   │ $0.15-0.40  │ 91% discount, minimal usage     │
│ Cloud Storage (10GB)        │ $0.05-0.15  │ Jenkins data + artifacts        │
│ Load Balancer (IAP)         │ $0.15-0.25  │ HTTPS + Identity-Aware Proxy    │
│ Networking (VPC, etc.)      │ $0.05-0.15  │ Private networking              │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ TOTAL ESTIMATED             │ $0.40-1.15  │ Well under $2 budget!           │
└─────────────────────────────┴─────────────┴─────────────────────────────────┘
EOF
    fi
    
    echo ""
    echo -e "${YELLOW}Ultra-Frugal Cost Optimization Features:${NC}"
    echo -e "${GREEN}• Cloud Run scales to ZERO when not building (no idle costs)${NC}"
    echo -e "${GREEN}• Spot VMs provide 91% discount vs regular instances${NC}"  
    echo -e "${GREEN}• Automatic agent termination prevents runaway costs${NC}"
    echo -e "${GREEN}• Storage lifecycle management (auto-cleanup old builds)${NC}"
    echo -e "${GREEN}• Regional deployment in us-central1 (lowest costs)${NC}"
    echo -e "${GREEN}• Identity-Aware Proxy instead of expensive VPN gateway${NC}"
    echo ""
    
    log_warning "IMPORTANT: Set up budget alerts in GCP Console for protection!"
    echo -e "${BLUE}Budget Alert Setup: https://console.cloud.google.com/billing/budgets${NC}"
    echo -e "${BLUE}Recommended: Set alerts at 50%, 80%, and 100% of \$2.00${NC}"
    echo ""
}

# Function to run terraform operations
run_terraform() {
    local operation="$1"
    local working_directory="$2"
    shift 2
    local args=("$@")
    
    local original_dir="$(pwd)"
    
    cd "$working_directory" || {
        log_error "Failed to change to directory: $working_directory"
        exit 1
    }
    
    local cmd="terraform $operation"
    if [[ ${#args[@]} -gt 0 ]]; then
        cmd+=" ${args[*]}"
    fi
    
    log_step "Running: $cmd"
    log_step "Working directory: $working_directory"
    
    # Execute terraform command
    if ! eval "$cmd"; then
        log_error "Terraform $operation failed"
        cd "$original_dir"
        exit 1
    fi
    
    cd "$original_dir"
}

# Function to display deployment results
show_deployment_results() {
    local working_directory="$1"
    
    log_header "🎉 Deployment Complete!"
    
    local original_dir="$(pwd)"
    cd "$working_directory" || {
        log_warning "Could not change to $working_directory to retrieve outputs"
        return
    }
    
    log_step "Retrieving deployment outputs..."
    
    # Get terraform outputs
    local outputs
    if outputs=$(terraform output -json 2>/dev/null); then
        echo -e "${GREEN}Your Ultra-Frugal Jenkins environment is ready!${NC}"
        echo -e "${CYAN}Environment: ${ENVIRONMENT^^}${NC}"
        echo ""
        
        # Display key information
        local jenkins_url project_id region authorized_users
        jenkins_url=$(echo "$outputs" | jq -r '.jenkins_url.value // empty' 2>/dev/null)
        project_id=$(echo "$outputs" | jq -r '.project_id.value // empty' 2>/dev/null)
        region=$(echo "$outputs" | jq -r '.region.value // empty' 2>/dev/null)
        authorized_users=$(echo "$outputs" | jq -r '.authorized_users.value[]? // empty' 2>/dev/null)
        
        if [[ -n "$jenkins_url" ]]; then
            echo -e "${CYAN}Jenkins URL: ${YELLOW}$jenkins_url${NC}"
        fi
        
        if [[ -n "$project_id" ]]; then
            echo -e "${CYAN}Project ID: ${YELLOW}$project_id${NC}"
        fi
        
        if [[ -n "$region" ]]; then
            echo -e "${CYAN}Region: ${YELLOW}$region${NC}"
        fi
        
        if [[ -n "$authorized_users" ]]; then
            echo -e "${CYAN}Authorized Users: ${YELLOW}$(echo "$authorized_users" | tr '\n' ', ' | sed 's/,$//')${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Access Instructions:${NC}"
        echo "1. Open the Jenkins URL above in your browser"
        echo "2. Sign in with your authorized Google account (IAP authentication)"
        echo "3. Alternative: Use admin/user with passwords from terraform.tfvars"
        echo "4. First startup may take 2-3 minutes (Cloud Run cold start)"
        echo ""
        
        echo -e "${CYAN}Next Steps:${NC}"
        echo "1. Create your first pipeline (see QUICK_START.md for sample)"
        echo "2. Set up budget alerts: https://console.cloud.google.com/billing/budgets"
        echo "3. Review security settings in Jenkins → Manage Jenkins"
        echo "4. Check docs/ULTRA_FRUGAL_GUIDE.md for advanced optimization tips"
        echo "5. Monitor costs in GCP Console billing section"
        echo ""
        
        echo -e "${CYAN}Useful Commands:${NC}"
        echo "• View all outputs: terraform output (in $working_directory)"
        echo "• Deploy to prod:   ./deploy.sh prod"
        echo "• Check costs:      Visit https://console.cloud.google.com/billing"
        echo "• Monitor services: gcloud run services list --region us-central1"
        echo "• Check agents:     gcloud compute instances list --filter='name:spot-agent*'"
        echo "• Clean up:         ./deploy.sh $ENVIRONMENT --destroy"
        
    else
        log_warning "No terraform outputs found. Deployment may have completed but outputs are not available."
        echo -e "${BLUE}You can manually check outputs later with: terraform output${NC}"
    fi
    
    cd "$original_dir"
    
    echo ""
    echo -e "${GREEN}Ultra-Frugal Jenkins deployment completed successfully!${NC}"
    echo -n -e "${GREEN}Estimated monthly cost: ${NC}"
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        echo -e "${YELLOW}\$0.85-2.00 (production)${NC}"
    else
        echo -e "${GREEN}\$0.40-1.15 (development)${NC}"
    fi
    echo ""
}

# Main deployment function
main_deployment() {
    log_header "🚀 Ultra-Frugal Jenkins Deployment"
    echo -e "${CYAN}Architecture: Google Cloud Best Practices${NC}"
    echo -e "${CYAN}Environment: ${ENVIRONMENT^^}${NC}"
    echo -e "${CYAN}Module: ultra-frugal-jenkins${NC}"
    echo -e "${CYAN}Target: Google Cloud Platform${NC}"
    echo -e "${CYAN}Technology: Cloud Run + Spot VMs + IAP${NC}"
    echo ""
    
    # Display project structure
    echo -e "${YELLOW}Project Structure:${NC}"
    echo -e "${WHITE}• Module: $MODULE_PATH${NC}"
    echo -e "${WHITE}• Environment: $ENVIRONMENT_PATH${NC}"
    echo ""
    
    # Validate prerequisites (unless skipped)
    if [[ "$SKIP_VALIDATION" == "false" ]]; then
        validate_prerequisites
    else
        log_warning "Skipping prerequisite validation as requested"
        # Still validate project structure even when skipping other validations
        validate_project_structure
    fi
    
    # Ensure environment directory exists
    if [[ ! -d "$ENVIRONMENT_PATH" ]]; then
        log_error "Environment path does not exist: $ENVIRONMENT_PATH"
        echo -e "${YELLOW}Available environments:${NC}"
        find environments -maxdepth 1 -type d ! -path environments | sed 's|environments/|  • |'
        exit 1
    fi
    
    # Read and validate project configuration
    local tfvars_path="$ENVIRONMENT_PATH/terraform.tfvars"
    if [[ -f "$tfvars_path" ]]; then
        local project_id
        if project_id=$(grep '^project_id' "$tfvars_path" | cut -d'"' -f2 2>/dev/null); then
            log_step "Found project ID in configuration: $project_id"
            
            # Validate project access
            if ! validate_project_access "$project_id"; then
                log_error "Cannot access project $project_id. Please check your permissions."
                echo -e "${YELLOW}Required permissions:${NC}"
                echo -e "${WHITE}• roles/editor or roles/owner on the project${NC}"
                echo -e "${WHITE}• Billing account linked to the project${NC}"
                exit 1
            fi
        else
            log_warning "Could not find project_id in $tfvars_path"
            echo -e "${YELLOW}Please ensure your terraform.tfvars contains: project_id = \"your-project-id\"${NC}"
        fi
    fi
    
    # Show cost estimate
    show_cost_estimate
    
    # Confirm deployment (unless forced or destroying)
    if [[ "$FORCE" == "false" ]]; then
        if [[ "$DESTROY" == "true" ]]; then
            echo -e "${RED}WARNING: This will DESTROY all resources in the $ENVIRONMENT environment!${NC}"
            echo -n -e "${RED}Do you want to continue with DESTRUCTION? [y/N]: ${NC}"
        else
            echo -n -e "${YELLOW}Do you want to continue with the deployment? [Y/n]: ${NC}"
        fi
        
        read -r confirmation
        
        if [[ "$DESTROY" == "true" ]]; then
            if [[ ! "$confirmation" =~ ^[yY](es)?$ ]]; then
                echo -e "${YELLOW}Destruction cancelled by user.${NC}"
                exit 0
            fi
        else
            if [[ -n "$confirmation" && ! "$confirmation" =~ ^[yY](es)?$ ]]; then
                echo -e "${YELLOW}Deployment cancelled by user.${NC}"
                exit 0
            fi
        fi
    fi
    
    # Initialize Terraform
    log_step "Initializing Terraform in environment: $ENVIRONMENT"
    run_terraform "init" "$ENVIRONMENT_PATH"
    log_success "Terraform initialized successfully"
    
    if [[ "$DESTROY" == "true" ]]; then
        # Destroy infrastructure
        log_header "🗑️  Destroying Infrastructure"
        log_warning "Destroying all resources in the $ENVIRONMENT environment..."
        
        run_terraform "destroy" "$ENVIRONMENT_PATH" "-auto-approve"
        log_success "Infrastructure destroyed successfully"
        
        echo ""
        echo -e "${GREEN}Environment $ENVIRONMENT has been cleaned up!${NC}"
        echo -e "${GREEN}All resources have been removed from GCP.${NC}"
        echo -e "${BLUE}You can redeploy anytime with: ./deploy.sh $ENVIRONMENT${NC}"
    else
        # Plan deployment
        log_step "Planning deployment for $ENVIRONMENT environment..."
        run_terraform "plan" "$ENVIRONMENT_PATH" "-out=tfplan"
        log_success "Terraform plan completed"
        
        # Apply deployment
        log_step "Applying deployment to $ENVIRONMENT environment..."
        run_terraform "apply" "$ENVIRONMENT_PATH" "tfplan"
        log_success "Terraform apply completed"
        
        # Show results
        show_deployment_results "$ENVIRONMENT_PATH"
    fi
}

# Main execution
main() {
    # Display script header
    echo ""
    echo -e "${MAGENTA}Ultra-Frugal Jenkins Deployment Script${NC}"
    echo -e "${MAGENTA}Following Google Cloud Terraform Best Practices${NC}"
    echo ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Ensure we're in the right directory (repo root)
    if [[ ! -d "$MODULE_PATH" ]]; then
        log_error "This script must be run from the repository root directory"
        echo ""
        echo -e "${YELLOW}Current directory: $(pwd)${NC}"
        echo -e "${YELLOW}Expected structure:${NC}"
        echo -e "${WHITE}  cloudrun-jenkins/${NC}"
        echo -e "${WHITE}  ├── modules/ultra-frugal-jenkins/${NC}"
        echo -e "${WHITE}  ├── environments/dev/${NC}"
        echo -e "${WHITE}  ├── environments/prod/${NC}"
        echo -e "${WHITE}  └── deploy.sh (this script)${NC}"
        echo ""
        echo -e "${BLUE}Please navigate to the repository root and try again.${NC}"
        exit 1
    fi
    
    # Run main deployment
    if ! main_deployment; then
        log_header "❌ Deployment Failed"
        log_error "Deployment failed with errors"
        echo ""
        echo -e "${YELLOW}🔧 Troubleshooting tips:${NC}"
        echo "1. Check your $ENVIRONMENT_PATH/terraform.tfvars configuration"
        echo "2. Verify GCP project permissions (need Editor or Owner role)"
        echo "3. Ensure all required GCP APIs are enabled"
        echo "4. Check the Terraform logs above for specific errors"
        echo "5. Verify billing account is linked to the project"
        echo "6. Confirm the specified region/zone is valid"
        echo ""
        echo -e "${BLUE}📚 Documentation:${NC}"
        echo "• Troubleshooting: docs/TROUBLESHOOTING.md"
        echo "• Quick Start: QUICK_START.md"
        echo "• Module docs: $MODULE_PATH/README.md"
        echo ""
        echo -e "${CYAN}🔄 Common fixes:${NC}"
        echo "• Run 'gcloud auth application-default login' for Terraform auth"
        echo "• Check quota limits in GCP Console"
        echo "• Ensure you're using a supported region"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"