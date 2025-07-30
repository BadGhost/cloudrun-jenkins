# Jenkins GCP Deployment Script for Windows PowerShell
# This script automates the deployment process on Windows

param(
    [switch]$Force,
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Jenkins GCP Deployment Script (Windows)" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check if gcloud is installed
try {
    $gcloudVersion = gcloud version 2>$null
    Write-Host "✅ Google Cloud SDK found" -ForegroundColor Green
} catch {
    Write-Host "❌ Google Cloud SDK is not installed. Please install it first." -ForegroundColor Red
    Write-Host "Download from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

# Check if terraform is installed
try {
    $terraformVersion = terraform version 2>$null
    Write-Host "✅ Terraform found" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform is not installed. Please install it first." -ForegroundColor Red
    Write-Host "Download from: https://www.terraform.io/downloads.html" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated with gcloud
try {
    $activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null
    if ([string]::IsNullOrEmpty($activeAccount)) {
        throw "No active account"
    }
    Write-Host "✅ Authenticated with Google Cloud as: $activeAccount" -ForegroundColor Green
} catch {
    Write-Host "❌ Not authenticated with Google Cloud. Please run 'gcloud auth login'" -ForegroundColor Red
    exit 1
}

# Check if terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "❌ terraform.tfvars file not found." -ForegroundColor Red
    Write-Host "Please copy terraform.tfvars.example to terraform.tfvars and update it with your values." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Prerequisites check passed" -ForegroundColor Green

# Get project ID from terraform.tfvars
try {
    $projectIdLine = Get-Content "terraform.tfvars" | Where-Object { $_ -match '^project_id\s*=' }
    $projectId = ($projectIdLine -split '=')[1].Trim().Trim('"')
    
    if ([string]::IsNullOrEmpty($projectId)) {
        throw "Project ID not found"
    }
    
    Write-Host "📋 Using project: $projectId" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Could not extract project ID from terraform.tfvars" -ForegroundColor Red
    exit 1
}

# Set the project
gcloud config set project $projectId

# Enable billing check
Write-Host "🔧 Checking billing account..." -ForegroundColor Yellow
try {
    $billingAccount = gcloud billing projects describe $projectId --format="value(billingAccountName)" 2>$null
    
    if ([string]::IsNullOrEmpty($billingAccount)) {
        Write-Host "❌ No billing account associated with project $projectId" -ForegroundColor Red
        Write-Host "Please associate a billing account with your project in the Google Cloud Console" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✅ Billing account configured" -ForegroundColor Green
} catch {
    Write-Host "❌ Error checking billing account. Please verify your project has billing enabled." -ForegroundColor Red
    exit 1
}

# Initialize Terraform
Write-Host "🔧 Initializing Terraform..." -ForegroundColor Yellow
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform initialization failed" -ForegroundColor Red
    exit 1
}

# Validate Terraform configuration
if (-not $SkipValidation) {
    Write-Host "🔍 Validating Terraform configuration..." -ForegroundColor Yellow
    terraform validate
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform validation failed" -ForegroundColor Red
        exit 1
    }
}

# Plan the deployment
Write-Host "📋 Planning deployment..." -ForegroundColor Yellow
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform planning failed" -ForegroundColor Red
    exit 1
}

# Ask for confirmation unless forced
if (-not $Force) {
    Write-Host ""
    Write-Host "🤔 Review the plan above. Do you want to proceed with the deployment?" -ForegroundColor Yellow
    $confirmation = Read-Host "Type 'yes' to continue"
    
    if ($confirmation -ne "yes") {
        Write-Host "❌ Deployment cancelled" -ForegroundColor Red
        Remove-Item "tfplan" -ErrorAction SilentlyContinue
        exit 1
    }
}

# Apply the configuration
Write-Host "🚀 Deploying infrastructure..." -ForegroundColor Green
terraform apply tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform apply failed" -ForegroundColor Red
    exit 1
}

# Clean up plan file
Remove-Item "tfplan" -ErrorAction SilentlyContinue

# Display success message and next steps
Write-Host ""
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "1. Update YOUR_HOME_PUBLIC_IP in network.tf with your actual public IP" -ForegroundColor White
Write-Host "2. Run 'terraform apply' again to update the VPN configuration" -ForegroundColor White
Write-Host "3. Configure your VPN client with the provided details (see docs/VPN_SETUP.md)" -ForegroundColor White
Write-Host "4. Access Jenkins using the provided URL" -ForegroundColor White
Write-Host ""
Write-Host "💰 Cost monitoring:" -ForegroundColor Cyan
Write-Host "- Check your GCP billing dashboard regularly" -ForegroundColor White
Write-Host "- Set up budget alerts for your project" -ForegroundColor White
Write-Host "- Monitor resource usage in Cloud Console" -ForegroundColor White
Write-Host ""
Write-Host "🔒 Security reminders:" -ForegroundColor Cyan
Write-Host "- Change default passwords after first login" -ForegroundColor White
Write-Host "- Review and customize Jenkins security settings" -ForegroundColor White
Write-Host "- Keep Jenkins and plugins updated" -ForegroundColor White
Write-Host ""
Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "- VPN Setup: docs/VPN_SETUP.md" -ForegroundColor White
Write-Host "- Cost Optimization: docs/COST_OPTIMIZATION.md" -ForegroundColor White
Write-Host "- Security Best Practices: docs/SECURITY_BEST_PRACTICES.md" -ForegroundColor White
Write-Host ""

# Get and display important outputs
Write-Host "📊 Deployment Information:" -ForegroundColor Cyan
try {
    $outputs = terraform output -json | ConvertFrom-Json
    Write-Host "VPN Gateway IP: $($outputs.vpn_gateway_ip.value)" -ForegroundColor Green
    Write-Host "Jenkins URL: $($outputs.jenkins_url.value)" -ForegroundColor Green
    Write-Host "Storage Bucket: $($outputs.jenkins_storage_bucket.value)" -ForegroundColor Green
} catch {
    Write-Host "Run 'terraform output' to see deployment details" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Happy building! 🏗️" -ForegroundColor Green
