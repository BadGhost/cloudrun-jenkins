# Quick Start Guide - Jenkins on GCP

This guide will get you up and running with Jenkins on GCP in under 30 minutes.

## Prerequisites

Before starting, ensure you have:

1. **Google Cloud Account** with billing enabled
2. **GCP Project** created
3. **Google Cloud SDK** installed
4. **Terraform** installed (>= 1.0)
5. **Your home public IP address**

## Step 1: Clone and Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd cloudrun-jenkins

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars
```

## Step 2: Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# Required: Your GCP project ID
project_id = "my-jenkins-project"

# Security: Set strong passwords
jenkins_admin_password = "SuperSecureAdminPassword123!"
jenkins_user_password  = "AnotherSecurePassword456!"

# VPN: Set a strong shared secret
vpn_shared_secret = "VeryLongAndSecureVPNSecret789!"

# Network: Your home IP range
client_ip_range = "192.168.1.0/24"  # Update this to your actual home network
```

## Step 3: Get Your Public IP

Find your home public IP address:

### Option 1: Use online service
Visit [whatismyipaddress.com](https://whatismyipaddress.com) and note your IPv4 address.

### Option 2: Use command line
```bash
# Windows PowerShell
(Invoke-WebRequest -Uri "https://ipinfo.io/ip").Content.Trim()

# Linux/Mac
curl -s https://ipinfo.io/ip
```

Update `network.tf` line 32 with your actual public IP:
```hcl
peer_ip = "YOUR_ACTUAL_PUBLIC_IP"  # Replace with your IP from above
```

## Step 4: Authenticate with Google Cloud

```bash
# Login to Google Cloud
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

## Step 5: Deploy Infrastructure

### Windows PowerShell
```powershell
# Make script executable and run
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deploy.ps1
```

### Linux/Mac
```bash
# Make script executable and run
chmod +x deploy.sh
./deploy.sh
```

### Manual Deployment
```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

## Step 6: Configure VPN Access

After deployment, you'll need to set up VPN access to reach Jenkins.

### Get VPN Details
```bash
# Get VPN gateway IP
terraform output vpn_gateway_ip

# Get other important details
terraform output
```

### Configure Your VPN Client

#### Windows 10/11
1. Open **Settings** > **Network & Internet** > **VPN**
2. Click **Add a VPN connection**
3. Configure:
   - **VPN provider**: Windows (built-in)
   - **Connection name**: Jenkins GCP
   - **Server name**: [VPN Gateway IP from terraform output]
   - **VPN type**: IKEv2
   - **Type of sign-in info**: Pre-shared key
   - **Pre-shared key**: [Your vpn_shared_secret from terraform.tfvars]

#### macOS
1. **System Preferences** > **Network** > **+**
2. **Interface**: VPN, **VPN Type**: IKEv2
3. **Server Address**: [VPN Gateway IP]
4. **Remote ID**: [VPN Gateway IP]
5. **Authentication Settings** > **Shared Secret**: [Your vpn_shared_secret]

For detailed VPN setup instructions, see `docs/VPN_SETUP.md`.

## Step 7: Access Jenkins

1. **Connect to VPN** using the configuration above
2. **Open Jenkins** using the URL from terraform output
3. **Login** with:
   - Username: `admin` Password: [Your jenkins_admin_password]
   - Username: `user` Password: [Your jenkins_user_password]

## Step 8: Initial Jenkins Configuration

### Install Additional Plugins (if needed)
1. Go to **Manage Jenkins** > **Manage Plugins**
2. Install any additional plugins you need
3. Restart Jenkins if required

### Configure Cloud Agents
1. Go to **Manage Jenkins** > **Manage Nodes and Clouds**
2. Click **Configure Clouds**
3. Verify the GCP configuration is correct
4. Test agent provisioning

### Create Your First Job
1. Click **New Item**
2. Choose **Pipeline** and give it a name
3. Use this sample pipeline:

```groovy
pipeline {
    agent {
        label 'docker'
    }
    
    stages {
        stage('Hello') {
            steps {
                echo 'Hello from Jenkins on GCP!'
                sh 'docker --version'
            }
        }
        
        stage('Build') {
            steps {
                echo 'This is where your build steps would go'
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed!'
        }
    }
}
```

## Step 9: Verify Cost Optimization

### Check Current Costs
1. Visit [GCP Billing Console](https://console.cloud.google.com/billing)
2. Navigate to your project's billing
3. Set up budget alerts for $2/month

### Monitor Resource Usage
```bash
# Check Cloud Run usage
gcloud run services describe jenkins-controller --region=asia-east1

# Check VM agent status
gcloud compute instances list --filter="name:jenkins-agent*"

# Check storage usage
gsutil du -sh gs://YOUR_PROJECT_ID-jenkins-storage
```

## Troubleshooting

### Common Issues

#### "Permission denied" errors
```bash
# Ensure you have the necessary IAM permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="user:YOUR_EMAIL@gmail.com" \
    --role="roles/owner"
```

#### VPN connection fails
1. Double-check your public IP in `network.tf`
2. Verify shared secret matches exactly
3. Check firewall on your local network

#### Jenkins doesn't start
```bash
# Check Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" --limit=50

# Check service status
gcloud run services describe jenkins-controller --region=asia-east1
```

#### Agent provisioning fails
1. Check IAM permissions for service account
2. Verify network configuration
3. Check agent startup script logs

### Getting Help

1. **Check logs**: Use GCP Console to view detailed logs
2. **Terraform state**: Run `terraform show` to see current state
3. **Documentation**: Review the docs/ folder for detailed guides
4. **Community**: Search for similar issues in Jenkins and GCP communities

## Next Steps

### Security Hardening
- Review `docs/SECURITY_BEST_PRACTICES.md`
- Change default passwords
- Enable additional security plugins

### Cost Optimization
- Review `docs/COST_OPTIMIZATION.md`
- Set up budget alerts
- Monitor usage patterns

### Advanced Configuration
- Configure webhooks for automatic builds
- Set up build notifications
- Integrate with your source control system

## Maintenance

### Weekly Tasks
- Check cost usage against budget
- Review security logs
- Update Jenkins plugins

### Monthly Tasks
- Review access permissions
- Update agent configurations
- Backup verification

### Quarterly Tasks
- Security assessment
- Performance optimization
- Infrastructure updates

## Cost Breakdown (Estimated)

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| Cloud Run Controller | $0.50 - $1.00 | Scales to zero when idle |
| VM Agents (preemptible) | $0.30 - $0.80 | 90% cost savings |
| Storage (10GB) | $0.20 - $0.40 | With lifecycle management |
| Networking | $0.30 - $0.50 | VPC + VPN costs |
| **Total** | **$1.30 - $2.70** | Within $2 budget target |

Congratulations! You now have a production-ready, cost-optimized Jenkins environment on GCP! 🎉
