# Jenkins Initial Setup and Common Issues

## Overview

This document covers the initial setup process for the Ultra-Frugal Jenkins deployment on GCP, including common issues and their solutions.

## Initial Password Issue

### Problem Description

When accessing Jenkins for the first time at `https://jenkins-<IP-with-dashes>.nip.io/jenkins`, you may encounter the "Getting Started" screen asking for an "Administrator password" instead of being able to use the configured credentials.

### Root Cause

This happens because:
1. Jenkins starts in initial setup mode by default
2. The Configuration as Code (JCasC) loads **after** the initial setup wizard
3. Jenkins generates its own temporary admin password for security during first-time setup
4. The `jenkins.install.runSetupWizard: false` setting in JCasC doesn't take effect until after the initial unlock

### Solution Steps

#### Step 1: Retrieve the Initial Admin Password

Use the following command to find the auto-generated password in the Cloud Run logs:

```bash
gcloud run services logs read jenkins-ultra-frugal --region=us-central1 --limit=200 | grep -A2 -B2 "following password"
```

Example output:
```
2025-07-31 02:15:23 Jenkins initial setup is required. An admin user has been created and a password generated.
2025-07-31 02:15:23 Please use the following password to proceed to installation:
2025-07-31 02:15:23 9103941c8fa94803bd8f1bbf9fac35fd
2025-07-31 02:15:23 This may also be found at: /var/jenkins_home/secrets/initialAdminPassword
```

#### Step 2: Complete Initial Setup

1. **Enter the generated password** (e.g., `9103941c8fa94803bd8f1bbf9fac35fd`) in the Jenkins unlock screen
2. **Skip plugin installation** or install suggested plugins (your choice)
3. **Create admin user** or skip and use existing configuration
4. **Complete the setup wizard**

#### Step 3: Use Configured Credentials

After the initial setup is complete, you can log in using the credentials configured in `terraform.tfvars`:

- **Username**: `admin`
- **Password**: Your configured password (e.g., `@Simonza01`)

Or:

- **Username**: `user` 
- **Password**: Your configured password (e.g., `@Simonza01`)

## Alternative: Automated Password Retrieval Script

Create a script to automatically retrieve the current initial admin password:

```bash
#!/bin/bash
# get-jenkins-password.sh

echo "🔍 Retrieving Jenkins initial admin password..."
PASSWORD=$(gcloud run services logs read jenkins-ultra-frugal --region=us-central1 --limit=200 | grep -A1 "Please use the following password" | tail -1 | tr -d ' ')

if [ -n "$PASSWORD" ] && [ ${#PASSWORD} -eq 32 ]; then
    echo "✅ Jenkins Initial Admin Password: $PASSWORD"
    echo ""
    echo "📋 Steps:"
    echo "1. Copy this password: $PASSWORD"
    echo "2. Paste it in the Jenkins unlock screen"
    echo "3. Complete the setup wizard"
    echo "4. Then use admin/@Simonza01 or user/@Simonza01"
else
    echo "❌ Could not find password. Checking recent logs..."
    gcloud run services logs read jenkins-ultra-frugal --region=us-central1 --limit=50 | grep -i password
fi
```

Make it executable and run:
```bash
chmod +x get-jenkins-password.sh
./get-jenkins-password.sh
```

## Configuration as Code (JCasC) Settings

The Jenkins configuration is defined in `modules/ultra-frugal-jenkins/config/jenkins-ultra-frugal.yaml`. Key settings include:

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${admin_password}"
        - id: "user"  
          password: "${user_password}"
```

And system properties:
```yaml
systemProperties:
  - key: "jenkins.install.runSetupWizard"
    value: "false"  # This only takes effect after initial unlock
```

## Troubleshooting

### Issue: Still seeing setup wizard after entering password

**Solution**: The password may have changed due to container restarts. Get the latest password:

```bash
gcloud run services logs read jenkins-ultra-frugal --region=us-central1 --limit=50 | grep -A1 "following password" | tail -1
```

### Issue: Configuration as Code not loading

**Cause**: JCasC loads after the initial setup is completed.

**Solution**: Complete the initial setup wizard first, then the JCasC configuration will be applied.

### Issue: Can't access Jenkins at all

**Check**: 
1. SSL certificate status: `gcloud compute ssl-certificates describe jenkins-ultra-ssl-v3 --global`
2. Cloud Run service status: `gcloud run services describe jenkins-ultra-frugal --region=us-central1`
3. Load balancer status via GCP Console

## Security Notes

- The initial admin password is only needed for the first-time setup
- After setup, use the strong passwords defined in your `terraform.tfvars`
- IAP (Identity-Aware Proxy) provides additional authentication layer
- All passwords are securely stored in Google Secret Manager

## Related Issues

- [SSL Certificate Setup](./SSL_CERTIFICATE_SETUP.md)
- [IAP Configuration](./SECURITY_BEST_PRACTICES.md)
- [Cost Optimization](./COST_OPTIMIZATION.md)
