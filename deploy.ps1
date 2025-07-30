#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploys Jenkins Ultra-Frugal infrastructure to Google Cloud Platform using Google Cloud best practices.

.DESCRIPTION
    This script automates the deployment of a cost-optimized Jenkins environment 
    on GCP using Terraform. It follows Google Cloud Terraform best practices with
    environment separation and module-based architecture.
    
    The script includes validation, deployment, and post-deployment verification 
    steps for both development and production environments.

.PARAMETER Environment
    The environment to deploy to (dev, prod). Default: dev
    - dev: Development environment with relaxed settings
    - prod: Production environment with enhanced security

.PARAMETER SkipValidation
    Skip prerequisite validation checks for faster deployment.

.PARAMETER Force
    Apply Terraform changes without interactive confirmation prompts.

.PARAMETER Destroy
    Destroy the infrastructure instead of creating it. Use with caution!

.EXAMPLE
    .\deploy.ps1
    Deploy to development environment with all validations.

.EXAMPLE
    .\deploy.ps1 -Environment prod -Force
    Deploy to production environment without confirmation prompts.

.EXAMPLE
    .\deploy.ps1 -Environment dev -Destroy
    Destroy the development environment.

.EXAMPLE
    .\deploy.ps1 -Environment dev -SkipValidation
    Deploy to development environment skipping prerequisite checks.

.NOTES
    Requires: PowerShell 5.1+, Google Cloud SDK, Terraform 1.0+
    
    This script follows Google Cloud Terraform best practices:
    - Module-based architecture (modules/ultra-frugal-jenkins/)
    - Environment separation (environments/dev/, environments/prod/)
    - Remote state management with GCS backends
    - Version pinning and dependency management
    - Cost optimization and security best practices
    
    Project Structure:
    cloudrun-jenkins/
    ├── modules/ultra-frugal-jenkins/    # Reusable Jenkins module
    ├── environments/
    │   ├── dev/                         # Development environment
    │   └── prod/                        # Production environment
    └── deploy.ps1                       # This deployment script

.LINK
    https://cloud.google.com/docs/terraform/best-practices-for-terraform
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',
    
    [switch]$SkipValidation,
    [switch]$Force,
    [switch]$Destroy
)

# Set error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Global variables
$script:ModulePath = "modules\ultra-frugal-jenkins"
$script:EnvironmentPath = "environments\$Environment"

# Color functions for better output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    
    $colors = @{
        'Red'     = [ConsoleColor]::Red
        'Green'   = [ConsoleColor]::Green
        'Yellow'  = [ConsoleColor]::Yellow
        'Blue'    = [ConsoleColor]::Blue
        'Cyan'    = [ConsoleColor]::Cyan
        'White'   = [ConsoleColor]::White
        'Magenta' = [ConsoleColor]::Magenta
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Write-Header {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "[STEP] $Message" -Color 'Blue'
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" -Color 'Green'
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" -Color 'Yellow'
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" -Color 'Red'
}

# Function to check if a command exists
function Test-CommandExists {
    param([string]$Command)
    
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to validate project structure
function Test-ProjectStructure {
    Write-Step "Validating project structure..."
    
    $requiredPaths = @(
        $script:ModulePath,
        "$($script:ModulePath)\main.tf",
        "$($script:ModulePath)\variables.tf",
        "$($script:ModulePath)\outputs.tf",
        "$($script:ModulePath)\versions.tf",
        $script:EnvironmentPath,
        "$($script:EnvironmentPath)\main.tf",
        "$($script:EnvironmentPath)\variables.tf",
        "$($script:EnvironmentPath)\outputs.tf",
        "$($script:EnvironmentPath)\versions.tf",
        "$($script:EnvironmentPath)\backend.tf"
    )
    
    $missingPaths = @()
    foreach ($path in $requiredPaths) {
        if (-not (Test-Path $path)) {
            $missingPaths += $path
        }
    }
    
    if ($missingPaths.Count -gt 0) {
        Write-Error "Project structure validation failed. Missing required files:"
        foreach ($path in $missingPaths) {
            Write-Host "  [MISSING] $path" -ForegroundColor Red
        }
        throw "Invalid project structure. Ensure you have the correct Google Cloud Terraform structure."
    }
    
    Write-Success "Project structure validation passed"
}

# Function to validate prerequisites
function Test-Prerequisites {
    Write-Step "Validating prerequisites..."
    
    $errors = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $errors += "PowerShell 5.1 or later is required. Current version: $($PSVersionTable.PSVersion)"
    }
    
    # Check if gcloud is installed and authenticated
    if (-not (Test-CommandExists 'gcloud')) {
        $errors += "Google Cloud SDK (gcloud) is not installed or not in PATH"
    }
    else {
        try {
            $gcloudAuth = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
            if (-not $gcloudAuth) {
                $errors += "No active Google Cloud authentication found. Run 'gcloud auth login'"
            }
            else {
                Write-Success "Authenticated as: $gcloudAuth"
            }
        }
        catch {
            $errors += "Unable to check Google Cloud authentication status"
        }
    }
    
    # Check if terraform is installed
    if (-not (Test-CommandExists 'terraform')) {
        $errors += "Terraform is not installed or not in PATH"
    }
    else {
        try {
            $terraformVersion = terraform version -json | ConvertFrom-Json
            $version = $terraformVersion.terraform_version
            Write-Success "Terraform version: $version"
            
            # Check if version is 1.0 or later
            $versionParts = $version.Split('.')
            if ([int]$versionParts[0] -lt 1) {
                $errors += "Terraform 1.0 or later is required. Current version: $version"
            }
        }
        catch {
            $errors += "Unable to determine Terraform version"
        }
    }
    
    # Validate project structure
    try {
        Test-ProjectStructure
    }
    catch {
        $errors += $_.Exception.Message
    }
    
    # Check if terraform.tfvars exists in environment
    $tfvarsPath = "$($script:EnvironmentPath)\terraform.tfvars"
    if (-not (Test-Path $tfvarsPath)) {
        $errors += "Configuration file not found: $tfvarsPath"
        $errors += "Copy from $($script:EnvironmentPath)\terraform.tfvars.example and customize."
    }
    
    if ($errors.Count -gt 0) {
        Write-Header "[ERROR] Prerequisite Check Failed"
        foreach ($error in $errors) {
            Write-Error $error
        }
        Write-Host ""
        Write-Warning "Please fix the above issues and try again."
        Write-Host ""
        Write-Host "Quick setup guide:" -ForegroundColor Cyan
        Write-Host "1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
        Write-Host "2. Install Terraform: https://terraform.io/downloads"
        Write-Host "3. Authenticate: gcloud auth login"
        Write-Host "4. Configure environment:"
        Write-Host "   cd $($script:EnvironmentPath)"
        Write-Host "   cp terraform.tfvars.example terraform.tfvars"
        Write-Host "   # Edit terraform.tfvars with your settings"
        Write-Host ""
        Write-Host "For detailed setup, see: QUICK_START.md" -ForegroundColor Blue
        exit 1
    }
    
    Write-Success "All prerequisites validated!"
}

# Function to get current GCP project
function Get-CurrentProject {
    try {
        $project = gcloud config get-value project 2>$null
        if ($project -and $project -ne "(unset)") {
            return $project
        }
        return $null
    }
    catch {
        return $null
    }
}

# Function to validate GCP project access
function Test-ProjectAccess {
    param([string]$ProjectId)
    
    Write-Step "Validating project access: $ProjectId"
    
    try {
        $project = gcloud projects describe $ProjectId --format="value(projectId)" 2>$null
        if ($project -eq $ProjectId) {
            Write-Success "Project access validated: $ProjectId"
            return $true
        }
        else {
            Write-Error "Cannot access project: $ProjectId"
            return $false
        }
    }
    catch {
        Write-Error "Error checking project access: $ProjectId"
        return $false
    }
}

# Function to check estimated costs based on environment
function Show-CostEstimate {
    Write-Header "[INFO] Estimated Monthly Costs"
    
    Write-Host "Ultra-Frugal Jenkins on GCP - Cost Breakdown:" -ForegroundColor Cyan
    Write-Host ""
    
    # Environment-specific cost estimates
    if ($Environment -eq 'prod') {
        $costs = @"
Environment: PRODUCTION

┌─────────────────────────────┬─────────────┬─────────────────────────────────┐
│ Component                   │ Monthly USD │ Notes                           │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ Cloud Run Controller        │ `$0.10-0.30  │ Higher traffic expected         │
│ Spot VM Agents (2-4 x e2)   │ `$0.30-0.80  │ 91% discount, auto-scaling      │
│ Cloud Storage (25GB)        │ `$0.10-0.25  │ More builds & artifacts         │
│ Load Balancer (IAP)         │ `$0.20-0.30  │ HTTPS + Identity-Aware Proxy    │
│ Networking (VPC, etc.)      │ `$0.10-0.20  │ Private networking              │
│ Monitoring & Logging        │ `$0.05-0.15  │ Enhanced production monitoring  │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ TOTAL ESTIMATED             │ `$0.85-2.00  │ At upper limit of budget        │
└─────────────────────────────┴─────────────┴─────────────────────────────────┘
"@
    }
    else {
        $costs = @"
Environment: DEVELOPMENT

┌─────────────────────────────┬─────────────┬─────────────────────────────────┐
│ Component                   │ Monthly USD │ Notes                           │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ Cloud Run Controller        │ `$0.00-0.20  │ Scales to zero when idle        │
│ Spot VM Agents (1-2 x e2)   │ `$0.15-0.40  │ 91% discount, minimal usage     │
│ Cloud Storage (10GB)        │ `$0.05-0.15  │ Jenkins data + artifacts        │
│ Load Balancer (IAP)         │ `$0.15-0.25  │ HTTPS + Identity-Aware Proxy    │
│ Networking (VPC, etc.)      │ `$0.05-0.15  │ Private networking              │
├─────────────────────────────┼─────────────┼─────────────────────────────────┤
│ TOTAL ESTIMATED             │ `$0.40-1.15  │ Well under `$2 budget!          │
└─────────────────────────────┴─────────────┴─────────────────────────────────┘
"@
    }
    
    Write-Host $costs -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Ultra-Frugal Cost Optimization Features:" -ForegroundColor Yellow
    Write-Host "• Cloud Run scales to ZERO when not building (no idle costs)" -ForegroundColor Green
    Write-Host "• Spot VMs provide 91% discount vs regular instances" -ForegroundColor Green  
    Write-Host "• Automatic agent termination prevents runaway costs" -ForegroundColor Green
    Write-Host "• Storage lifecycle management (auto-cleanup old builds)" -ForegroundColor Green
    Write-Host "• Regional deployment in us-central1 (lowest costs)" -ForegroundColor Green
    Write-Host "• Identity-Aware Proxy instead of expensive VPN gateway" -ForegroundColor Green
    Write-Host ""
    
    Write-Warning "IMPORTANT: Set up budget alerts in GCP Console for protection!"
    Write-Host "Budget Alert Setup: https://console.cloud.google.com/billing/budgets" -ForegroundColor Blue
    Write-Host "Recommended: Set alerts at 50%, 80%, and 100% of `$2.00" -ForegroundColor Blue
    Write-Host ""
}

# Function to run terraform operations
function Invoke-Terraform {
    param(
        [string]$Operation,
        [string]$WorkingDirectory,
        [string[]]$Arguments = @()
    )
    
    $originalLocation = Get-Location
    try {
        Set-Location $WorkingDirectory
        
        $cmd = "terraform $Operation"
        if ($Arguments.Count -gt 0) {
            $cmd += " " + ($Arguments -join " ")
        }
        
        Write-Step "Running: $cmd"
        Write-Step "Working directory: $WorkingDirectory"
        
        # Execute terraform command
        $result = Invoke-Expression $cmd
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform $Operation failed with exit code $LASTEXITCODE"
        }
        
        return $result
    }
    finally {
        Set-Location $originalLocation
    }
}

# Function to display deployment results
function Show-DeploymentResults {
    param([string]$WorkingDirectory)
    
    Write-Header "[SUCCESS] Deployment Complete!"
    
    $originalLocation = Get-Location
    try {
        Set-Location $WorkingDirectory
        
        Write-Step "Retrieving deployment outputs..."
        
        # Get terraform outputs
        $outputs = terraform output -json | ConvertFrom-Json
        
        if ($outputs) {
            Write-Host "Your Ultra-Frugal Jenkins environment is ready!" -ForegroundColor Green
            Write-Host "Environment: $($Environment.ToUpper())" -ForegroundColor Cyan
            Write-Host ""
            
            # Display key information
            if ($outputs.jenkins_url -and $outputs.jenkins_url.value) {
                Write-Host "Jenkins URL: " -NoNewline -ForegroundColor Cyan
                Write-Host $outputs.jenkins_url.value -ForegroundColor Yellow
            }
            
            if ($outputs.project_id -and $outputs.project_id.value) {
                Write-Host "Project ID: " -NoNewline -ForegroundColor Cyan
                Write-Host $outputs.project_id.value -ForegroundColor Yellow
            }
            
            if ($outputs.region -and $outputs.region.value) {
                Write-Host "Region: " -NoNewline -ForegroundColor Cyan
                Write-Host $outputs.region.value -ForegroundColor Yellow
            }
            
            # Show IAP users if available
            if ($outputs.authorized_users -and $outputs.authorized_users.value) {
                Write-Host "Authorized Users: " -NoNewline -ForegroundColor Cyan
                Write-Host ($outputs.authorized_users.value -join ", ") -ForegroundColor Yellow
            }
            
            Write-Host ""
            Write-Host "Access Instructions:" -ForegroundColor Cyan
            Write-Host "1. Open the Jenkins URL above in your browser"
            Write-Host "2. Sign in with your authorized Google account (IAP authentication)"
            Write-Host "3. Alternative: Use admin/user with passwords from terraform.tfvars"
            Write-Host "4. First startup may take 2-3 minutes (Cloud Run cold start)"
            Write-Host ""
            
            Write-Host "Next Steps:" -ForegroundColor Cyan
            Write-Host "1. Create your first pipeline (see QUICK_START.md for sample)"
            Write-Host "2. Set up budget alerts: https://console.cloud.google.com/billing/budgets"
            Write-Host "3. Review security settings in Jenkins → Manage Jenkins"
            Write-Host "4. Check docs/ULTRA_FRUGAL_GUIDE.md for advanced optimization tips"
            Write-Host "5. Monitor costs in GCP Console billing section"
            Write-Host ""
            
            Write-Host "Useful Commands:" -ForegroundColor Cyan
            Write-Host "• View all outputs: terraform output (in $WorkingDirectory)"
            Write-Host "• Deploy to prod:   .\deploy.ps1 -Environment prod"
            Write-Host "• Check costs:      Visit https://console.cloud.google.com/billing"
            Write-Host "• Monitor services: gcloud run services list --region us-central1"
            Write-Host "• Check agents:     gcloud compute instances list --filter='name:spot-agent*'"
            Write-Host "• Clean up:         .\deploy.ps1 -Environment $Environment -Destroy"
            
        }
        else {
            Write-Warning "No terraform outputs found. Deployment may have completed but outputs are not available."
            Write-Host "You can manually check outputs later with: terraform output" -ForegroundColor Blue
        }
    }
    catch {
        Write-Warning "Could not retrieve deployment outputs: $($_.Exception.Message)"
        Write-Host "You can manually check outputs later with: terraform output (in $WorkingDirectory)" -ForegroundColor Blue
    }
    finally {
        Set-Location $originalLocation
    }
    
    Write-Host ""
    Write-Host "Ultra-Frugal Jenkins deployment completed successfully!" -ForegroundColor Green
    Write-Host "Estimated monthly cost: " -NoNewline -ForegroundColor Green
    if ($Environment -eq 'prod') {
        Write-Host "`$0.85-2.00 (production)" -ForegroundColor Yellow
    } else {
        Write-Host "`$0.40-1.15 (development)" -ForegroundColor Green
    }
    Write-Host ""
}

# Main deployment function
function Start-Deployment {
    Write-Header "[INFO] Ultra-Frugal Jenkins Deployment"
    Write-Host "Architecture: Google Cloud Best Practices" -ForegroundColor Cyan
    Write-Host "Environment: $($Environment.ToUpper())" -ForegroundColor Cyan
    Write-Host "Module: ultra-frugal-jenkins" -ForegroundColor Cyan
    Write-Host "Target: Google Cloud Platform" -ForegroundColor Cyan
    Write-Host "Technology: Cloud Run + Spot VMs + IAP" -ForegroundColor Cyan
    Write-Host ""
    
    # Display project structure
    Write-Host "Project Structure:" -ForegroundColor Yellow
    Write-Host "• Module: $script:ModulePath" -ForegroundColor White
    Write-Host "• Environment: $script:EnvironmentPath" -ForegroundColor White
    Write-Host ""
    
    # Validate prerequisites (unless skipped)
    if (-not $SkipValidation) {
        Test-Prerequisites
    }
    else {
        Write-Warning "Skipping prerequisite validation as requested"
        # Still validate project structure even when skipping other validations
        Test-ProjectStructure
    }
    
    # Ensure environment directory exists
    if (-not (Test-Path $script:EnvironmentPath)) {
        Write-Error "Environment path does not exist: $script:EnvironmentPath"
        Write-Host "Available environments:" -ForegroundColor Yellow
        Get-ChildItem "environments" -Directory | ForEach-Object { Write-Host "  • $($_.Name)" -ForegroundColor White }
        exit 1
    }
    
    # Read and validate project configuration
    $tfvarsPath = "$($script:EnvironmentPath)\terraform.tfvars"
    if (Test-Path $tfvarsPath) {
        $tfvarsContent = Get-Content $tfvarsPath -Raw
        if ($tfvarsContent -match 'project_id\s*=\s*["\']([^"\']+)["\']') {
            $projectId = $matches[1]
            Write-Step "Found project ID in configuration: $projectId"
            
            # Validate project access
            if (-not (Test-ProjectAccess $projectId)) {
                Write-Error "Cannot access project $projectId. Please check your permissions."
                Write-Host "Required permissions:" -ForegroundColor Yellow
                Write-Host "• roles/editor or roles/owner on the project" -ForegroundColor White
                Write-Host "• Billing account linked to the project" -ForegroundColor White
                exit 1
            }
        }
        else {
            Write-Warning "Could not find project_id in $tfvarsPath"
            Write-Host "Please ensure your terraform.tfvars contains: project_id = \"your-project-id\"" -ForegroundColor Yellow
        }
    }
    
    # Show cost estimate
    Show-CostEstimate
    
    # Confirm deployment (unless forced or destroying)
    if (-not $Force -and -not $Destroy) {
        if ($Destroy) {
            Write-Host "WARNING: This will DESTROY all resources in the $Environment environment!" -ForegroundColor Red
            Write-Host "Do you want to continue with DESTRUCTION? [y/N]: " -NoNewline -ForegroundColor Red
        } else {
            Write-Host "Do you want to continue with the deployment? [Y/n]: " -NoNewline -ForegroundColor Yellow
        }
        
        $confirmation = Read-Host
        
        if ($Destroy) {
            if ($confirmation.ToLower() -notin @('y', 'yes')) {
                Write-Host "Destruction cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        } else {
            if ($confirmation -and $confirmation.ToLower() -notin @('y', 'yes', '')) {
                Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        }
    }
    
    try {
        # Initialize Terraform
        Write-Step "Initializing Terraform in environment: $Environment"
        Invoke-Terraform -Operation "init" -WorkingDirectory $script:EnvironmentPath
        Write-Success "Terraform initialized successfully"
        
        if ($Destroy) {
            # Destroy infrastructure
            Write-Header "[INFO] Destroying Infrastructure"
            Write-Warning "Destroying all resources in the $Environment environment..."
            
            $destroyArgs = @("-auto-approve")
            Invoke-Terraform -Operation "destroy" -WorkingDirectory $script:EnvironmentPath -Arguments $destroyArgs
            Write-Success "Infrastructure destroyed successfully"
            
            Write-Host ""
            Write-Host "Environment $Environment has been cleaned up!" -ForegroundColor Green
            Write-Host "All resources have been removed from GCP." -ForegroundColor Green
            Write-Host "You can redeploy anytime with: .\deploy.ps1 -Environment $Environment" -ForegroundColor Blue
        }
        else {
            # Plan deployment
            Write-Step "Planning deployment for $Environment environment..."
            Invoke-Terraform -Operation "plan" -WorkingDirectory $script:EnvironmentPath -Arguments @("-out=tfplan")
            Write-Success "Terraform plan completed"
            
            # Apply deployment
            Write-Step "Applying deployment to $Environment environment..."
            $applyArgs = @("tfplan")
            Invoke-Terraform -Operation "apply" -WorkingDirectory $script:EnvironmentPath -Arguments $applyArgs
            Write-Success "Terraform apply completed"
            
            # Show results
            Show-DeploymentResults -WorkingDirectory $script:EnvironmentPath
        }
        
    }
    catch {
        Write-Header "[ERROR] Deployment Failed"
        Write-Error "Deployment failed: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Check your $tfvarsPath configuration"
        Write-Host "2. Verify GCP project permissions (need Editor or Owner role)"
        Write-Host "3. Ensure all required GCP APIs are enabled"
        Write-Host "4. Check the Terraform logs above for specific errors"
        Write-Host "5. Verify billing account is linked to the project"
        Write-Host "6. Confirm the specified region/zone is valid"
        Write-Host ""
        Write-Host "Documentation:" -ForegroundColor Blue
        Write-Host "• Troubleshooting: docs/TROUBLESHOOTING.md"
        Write-Host "• Quick Start: QUICK_START.md"
        Write-Host "• Module docs: $script:ModulePath/README.md"
        Write-Host ""
        Write-Host "Common fixes:" -ForegroundColor Cyan
        Write-Host "• Run 'gcloud auth application-default login' for Terraform auth"
        Write-Host "• Check quota limits in GCP Console"
        Write-Host "• Ensure you're using a supported region"
        exit 1
    }
}

# Main execution
try {
    # Display script header
    Write-Host ""
    Write-Host "Ultra-Frugal Jenkins Deployment Script" -ForegroundColor Magenta
    Write-Host "Following Google Cloud Terraform Best Practices" -ForegroundColor Magenta
    Write-Host ""
    
    # Ensure we're in the right directory (repo root)
    if (-not (Test-Path $script:ModulePath)) {
        Write-Error "This script must be run from the repository root directory"
        Write-Host ""
        Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
        Write-Host "Expected structure:" -ForegroundColor Yellow
        Write-Host "  cloudrun-jenkins/" -ForegroundColor White
        Write-Host "  ├── modules/ultra-frugal-jenkins/" -ForegroundColor White
        Write-Host "  ├── environments/dev/" -ForegroundColor White
        Write-Host "  ├── environments/prod/" -ForegroundColor White
        Write-Host "  └── deploy.ps1 (this script)" -ForegroundColor White
        Write-Host ""
        Write-Host "Please navigate to the repository root and try again." -ForegroundColor Blue
        exit 1
    }
    
    Start-Deployment
}
catch {
    Write-Header "[ERROR] Script Execution Failed"
    Write-Error "Unexpected error: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Debug information:" -ForegroundColor Yellow
    Write-Host "Script location: $PSCommandPath" -ForegroundColor White
    Write-Host "Working directory: $(Get-Location)" -ForegroundColor White
    Write-Host "Environment: $Environment" -ForegroundColor White
    Write-Host "Module path: $script:ModulePath" -ForegroundColor White
    Write-Host "Environment path: $script:EnvironmentPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor White
    exit