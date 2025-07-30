#!/bin/bash

# Jenkins Deployment Script
# This script automates the deployment process

set -e

echo "🚀 Jenkins GCP Deployment Script"
echo "================================="

# Check prerequisites
echo "Checking prerequisites..."

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK is not installed. Please install it first."
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first."
    exit 1
fi

# Check if authenticated with gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Not authenticated with Google Cloud. Please run 'gcloud auth login'"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars file not found. Please copy terraform.tfvars.example and update it."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Get project ID from terraform.tfvars
PROJECT_ID=$(grep '^project_id' terraform.tfvars | cut -d'"' -f2)

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID not found in terraform.tfvars"
    exit 1
fi

echo "📋 Using project: $PROJECT_ID"

# Set the project
gcloud config set project $PROJECT_ID

# Enable billing if not already enabled
echo "🔧 Checking billing account..."
BILLING_ACCOUNT=$(gcloud billing projects describe $PROJECT_ID --format="value(billingAccountName)" 2>/dev/null || echo "")

if [ -z "$BILLING_ACCOUNT" ]; then
    echo "❌ No billing account associated with project $PROJECT_ID"
    echo "Please associate a billing account with your project in the Google Cloud Console"
    exit 1
fi

echo "✅ Billing account configured"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate Terraform configuration
echo "🔍 Validating Terraform configuration..."
terraform validate

# Plan the deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo ""
echo "🤔 Review the plan above. Do you want to proceed with the deployment?"
read -p "Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Apply the configuration
echo "🚀 Deploying infrastructure..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Update YOUR_HOME_PUBLIC_IP in network.tf with your actual public IP"
echo "2. Run 'terraform apply' again to update the VPN configuration"
echo "3. Configure your VPN client with the provided details"
echo "4. Access Jenkins using the provided URL"
echo ""
echo "💰 Cost monitoring:"
echo "- Check your GCP billing dashboard regularly"
echo "- Set up budget alerts for your project"
echo "- Monitor resource usage in Cloud Console"
echo ""
echo "🔒 Security reminders:"
echo "- Change default passwords after first login"
echo "- Review and customize Jenkins security settings"
echo "- Keep Jenkins and plugins updated"
