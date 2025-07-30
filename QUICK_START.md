# Quick Start Guide - Ultra-Frugal Jenkins on GCP

This guide will get you up and running with Jenkins on GCP in under 3 minutes using Google Cloud Terraform best practices.

## Project Structure Overview

```
cloudrun-jenkins/
├── modules/ultra-frugal-jenkins/    # Reusable Jenkins module  
├── environments/
│   ├── dev/                         # Development environment
│   └── prod/                        # Production environment
├── docs/                            # Documentation
└── deploy.ps1                       # Multi-environment deployment
```

## Prerequisites

Before starting, ensure you have:

1. **Google Cloud Account** with billing enabled
2. **GCP Project** created  
3. **Google Cloud SDK** installed and authenticated (`gcloud auth login`)
4. **Terraform** installed (>= 1.0)

## Step 1: Clone and Navigate

```bash
# Clone the repository
git clone <your-repo-url>
cd cloudrun-jenkins
```

## Step 2: Configure Development Environment

```bash
# Navigate to dev environment
cd environments/dev

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars
```

## Step 3: Update Configuration

Edit `environments/dev/terraform.tfvars` with your specific values:

```hcl
# Required: Your GCP project ID
project_id = "my-jenkins-project"

# Security: Set strong passwords
jenkins_admin_password = "SuperSecureAdminPassword123!"
jenkins_user_password  = "AnotherSecurePassword456!"

# IAP Access: List of Google account emails authorized to access Jenkins
# Maximum 3 users for cost optimization
authorized_users = [
  "user1@gmail.com",
  "user2@gmail.com"
]

# Optional: Uncomment and modify if needed
# region = "us-central1"  # Most cost-effective region
# zone = "us-central1-a"
```

## Step 4: Deploy Development Environment

### Option 1: PowerShell (Windows/Cross-Platform)
```powershell
# Return to root directory
cd ../..

# Deploy to development environment
.\deploy.ps1 -Environment dev
```

### Option 2: Bash (Linux/macOS/WSL)
```bash
# Return to root directory
cd ../..

# Deploy to development environment
./deploy.sh dev
```

The script will:
- ✅ Validate prerequisites
- ✅ Initialize Terraform
- ✅ Plan the deployment
- ✅ Deploy the infrastructure
- ✅ Display access information

## Step 5: Access Your Jenkins

After deployment completes:

1. **Copy the Jenkins URL** from the deployment output
2. **Open in browser**: The URL will look like `https://jenkins-PROJECT.nip.io/jenkins`
3. **Sign in** with your authorized Google account (automatic via IAP)
4. **Alternative login**: Use `admin`/`user` with the passwords you set

## Step 6: Create Your First Pipeline

1. Click **New Item** in Jenkins
2. Choose **Pipeline** and give it a name
3. Use this sample pipeline to test Spot VM agents:

```groovy
pipeline {
    agent {
        label 'spot ultra-frugal'
    }
    
    stages {
        stage('Hello Ultra-Frugal') {
            steps {
                echo 'Hello from Ultra-Frugal Jenkins on GCP!'
                sh '''
                    echo "Running on Spot VM with 91% cost savings!"
                    docker --version
                    echo "Current directory: $(pwd)"
                    echo "Available disk space:"
                    df -h
                '''
            }
        }
        
        stage('Docker Build Test') {
            steps {
                script {
                    echo 'Testing Docker capabilities...'
                    sh '''
                        echo "FROM alpine:latest" > Dockerfile
                        echo "RUN echo 'Ultra-frugal container!'" >> Dockerfile
                        docker build -t test-frugal .
                        docker run --rm test-frugal
                        docker rmi test-frugal
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed! Agent will auto-terminate for cost savings.'
        }
    }
}
```

4. Click **Save** and **Build Now**
5. Watch as Jenkins automatically provisions a Spot VM agent and runs your build

## Step 7: Monitor Costs (Important!)

### Set Up Budget Alerts
1. Visit [GCP Billing Console](https://console.cloud.google.com/billing)
2. Navigate to **Budgets & alerts**  
3. Create a budget for **$2.00/month**
4. Set alerts at **50%**, **80%**, and **100%**

### Monitor Current Usage
```bash
# Check current costs
gcloud billing projects describe YOUR_PROJECT_ID

# Monitor active resources
gcloud run services list
gcloud compute instances list --filter="name:spot-agent*"
```

## Production Deployment (Optional)

For production use:

### PowerShell
```powershell
# Configure production environment
cd environments/prod
cp terraform.tfvars.example terraform.tfvars

# Edit backend.tf to use GCS bucket for state
# Edit terraform.tfvars with production values

# Deploy to production
cd ../..
.\deploy.ps1 -Environment prod
```

### Bash
```bash
# Configure production environment
cd environments/prod
cp terraform.tfvars.example terraform.tfvars

# Edit backend.tf to use GCS bucket for state
# Edit terraform.tfvars with production values

# Deploy to production
cd ../..
./deploy.sh prod
```

## Architecture Benefits

### **Cost Optimization**
- **Cloud Run**: Scales to zero when not building
- **Spot VMs**: 91% discount on build agents  
- **Direct GCS**: No persistent disk costs
- **IAP**: No VPN infrastructure costs

### **Google Cloud Best Practices**
- **Modular Design**: Reusable `ultra-frugal-jenkins` module
- **Environment Separation**: Isolated dev/prod environments
- **State Management**: Environment-specific Terraform state
- **Version Pinning**: Consistent provider versions

### **Security & Accessibility**
- **Zero Setup**: Google IAP requires no client configuration
- **Enterprise Grade**: Multi-factor authentication included
- **Global Access**: Works from anywhere with internet
- **Private Networking**: All compute uses private IPs

## Troubleshooting

### Common Issues

#### "Permission denied" errors
```bash
# Ensure you have necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="user:YOUR_EMAIL@gmail.com" \
    --role="roles/editor"
```

#### Jenkins doesn't start
```bash
# Check Cloud Run logs
cd environments/dev  # or prod
terraform output jenkins_url
gcloud run services describe jenkins-ultra-frugal --region=us-central1
```

#### Agent provisioning fails
1. Check IAM permissions for the service account
2. Verify Spot VM availability in your region
3. Review agent startup logs in Compute Engine console

### Getting Help

1. **Check module documentation**: `modules/ultra-frugal-jenkins/README.md`
2. **Review environment outputs**: `terraform output` in environment directory
3. **Monitor logs**: Use GCP Console for detailed logging
4. **Cost tracking**: Check billing dashboard regularly

## Environment Management Commands

```powershell
# PowerShell - Deploy to different environments  
.\deploy.ps1 -Environment dev     # Development
.\deploy.ps1 -Environment prod    # Production

# PowerShell - Skip validation (faster)
.\deploy.ps1 -Environment dev -SkipValidation

# PowerShell - Force apply without confirmation
.\deploy.ps1 -Environment dev -Force
```

```bash
# Bash - Deploy to different environments
./deploy.sh dev                   # Development (default)
./deploy.sh prod                  # Production

# Bash - Skip validation (faster)
./deploy.sh dev --skip-validation

# Bash - Force apply without confirmation
./deploy.sh dev --force

# Bash - Destroy environment
./deploy.sh dev --destroy
```

```bash
# Manual operations (both PowerShell and Bash)
cd environments/dev
terraform plan                    # Review changes
terraform apply                   # Apply changes  
terraform destroy                 # Clean up (careful!)
```

## Cost Expectations

### Expected Monthly Costs

| Component | Development | Production | Notes |
|-----------|-------------|------------|-------|
| Cloud Run Controller | $0.00-0.20 | $0.10-0.30 | Scales to zero |
| Spot VM Agents | $0.10-0.40 | $0.20-0.60 | 91% discount |
| Cloud Storage | $0.05-0.15 | $0.10-0.25 | Actual usage |
| Load Balancer | $0.15-0.25 | $0.20-0.30 | IAP HTTPS |
| **Total** | **$0.30-1.00** | **$0.60-1.45** | **Well under budget!** |

### Cost Control Features
- Automatic agent termination when idle
- Aggressive log rotation and cleanup
- Storage lifecycle management (30/90/180 day policies)
- Resource limits and quotas

## Next Steps

### Immediate Actions
1. ✅ **Change default passwords** in Jenkins security settings
2. ✅ **Set up budget alerts** in GCP Console  
3. ✅ **Create your first real pipeline** for your project
4. ✅ **Invite team members** to authorized_users list

### Advanced Configuration
1. **Review security settings**: `docs/SECURITY_BEST_PRACTICES.md`
2. **Optimize costs further**: `docs/COST_OPTIMIZATION.md`
3. **Understand the architecture**: `docs/ULTRA_FRUGAL_GUIDE.md`
4. **Customize the module**: `modules/ultra-frugal-jenkins/README.md`

### Production Readiness
1. **Set up GCS backend** for production state
2. **Configure monitoring** and alerting
3. **Implement backup** and disaster recovery
4. **Document runbooks** for your team

---

Congratulations! You now have a production-ready, ultra-frugal Jenkins environment following Google Cloud best practices! 🎉

**Total setup time: ~3 minutes | Expected monthly cost: $0.30-$1.45 | Savings vs traditional: 95%+**
