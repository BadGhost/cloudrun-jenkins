# Security Best Practices for Jenkins on GCP

This guide outlines the security measures implemented and additional recommendations for your Jenkins deployment.

## Implemented Security Features

### 1. Network Security
- **Private Cloud Run**: No public endpoints, VPN-only access
- **VPC Isolation**: Dedicated VPC with controlled access
- **Firewall Rules**: Restrictive rules allowing only necessary traffic
- **No External IPs**: VM agents use private IPs only

### 2. Identity and Access Management
- **Service Accounts**: Dedicated service accounts with minimal permissions
- **IAM Roles**: Least privilege principle applied
- **Secret Management**: Passwords stored in Google Secret Manager
- **Authentication**: Jenkins built-in user database with strong passwords

### 3. Data Protection
- **Encryption at Rest**: All data encrypted by default
- **Encryption in Transit**: HTTPS/TLS enforced
- **Backup Security**: Automated backups with access controls
- **Audit Logging**: Comprehensive logging enabled

## Additional Security Hardening

### 1. Jenkins Configuration

#### Security Realm Enhancement
Add to your Jenkins configuration:
```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      enableCaptcha: true
      users:
        - id: "admin"
          password: "${admin_password}"
          properties:
            - "hudson.security.HudsonPrivateSecurityRealm$Details":
                passwordHash: "{JBCRYPT}$2a$10$..."
            - "hudson.tasks.Mailer$UserProperty":
                emailAddress: "admin@yourdomain.com"
```

#### CSRF Protection
```yaml
security:
  crumbIssuer:
    standard:
      excludeClientIPFromCrumb: false
  
  # Additional security headers
  httpHeaders:
    - name: "X-Frame-Options"
      value: "DENY"
    - name: "X-Content-Type-Options"
      value: "nosniff"
    - name: "X-XSS-Protection"
      value: "1; mode=block"
```

### 2. Plugin Security

#### Required Security Plugins
Add to `plugins.txt`:
```
# Security plugins
matrix-auth:3.1.5
build-timeout:1.27
authorize-project:1.4.0
permissive-script-security:0.7
script-security:1.78
antisamy-markup-formatter:2.7
```

#### Plugin Management Strategy
```groovy
// Disable plugin installation by non-admins
Jenkins.instance.getDescriptor("hudson.model.UpdateCenter").doSafeRestart = { ->
    throw new Exception("Plugin management restricted")
}
```

### 3. Job Security

#### Pipeline Security
```groovy
// Secure pipeline template
pipeline {
    agent { label 'docker' }
    
    options {
        // Security options
        skipDefaultCheckout(true)
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(
            numToKeepStr: '10',
            daysToKeepStr: '30'
        ))
    }
    
    environment {
        // Secure environment setup
        DOCKER_BUILDKIT = '1'
        COMPOSE_DOCKER_CLI_BUILD = '1'
    }
    
    stages {
        stage('Secure Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[$class: 'CloneOption', depth: 1, shallow: true]],
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/yourusername/yourrepo.git',
                        credentialsId: 'github-token'
                    ]]
                ])
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    // Container security scanning
                    sh '''
                        docker run --rm -v $(pwd):/workspace \
                        aquasec/trivy:latest fs /workspace
                    '''
                }
            }
        }
    }
    
    post {
        always {
            // Clean workspace
            cleanWs()
        }
    }
}
```

### 4. Credential Management

#### Secure Credential Storage
```groovy
// Script to add credentials securely
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*

// AWS credentials
def awsCredentials = new BasicAWSCredentials(
    CredentialsScope.GLOBAL,
    "aws-credentials",
    "AWS Credentials",
    "ACCESS_KEY_ID",
    "SECRET_ACCESS_KEY"
)

// GitHub token
def githubToken = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "github-token",
    "GitHub Token",
    Secret.fromString("your_github_token")
)

SystemCredentialsProvider.getInstance().getStore().addCredentials(
    Domain.global(), awsCredentials
)
SystemCredentialsProvider.getInstance().getStore().addCredentials(
    Domain.global(), githubToken
)
```

### 5. Monitoring and Alerting

#### Security Event Monitoring
```yaml
# Cloud Logging filter for security events
resource.type="cloud_run_revision"
jsonPayload.message=~"(failed|unauthorized|forbidden|error)"
```

#### Audit Logging
```groovy
// Jenkins audit plugin configuration
import hudson.security.GlobalMatrixAuthorizationStrategy
import jenkins.model.Jenkins

def jenkins = Jenkins.getInstance()
def strategy = new GlobalMatrixAuthorizationStrategy()

// Enable audit logging
jenkins.getDescriptor("hudson.security.GlobalMatrixAuthorizationStrategy")
    .setAuditTrail(true)
```

### 6. Regular Security Tasks

#### Weekly Security Checklist
```bash
#!/bin/bash
# weekly_security_check.sh

echo "🔒 Weekly Jenkins Security Check"
echo "==============================="

# 1. Check for plugin updates
echo "Checking plugin updates..."
curl -s "http://jenkins-url/pluginManager/api/json?depth=1" | \
    jq -r '.plugins[] | select(.hasUpdate==true) | .shortName'

# 2. Review access logs
echo "Reviewing access patterns..."
gcloud logging read "resource.type=cloud_run_revision" \
    --freshness=7d --format="table(timestamp,jsonPayload.message)"

# 3. Check for failed logins
echo "Checking authentication failures..."
# Add specific log filtering here

# 4. Verify backup integrity
echo "Verifying backup integrity..."
gsutil ls -l gs://your-jenkins-storage/backups/

# 5. Update security patches
echo "Checking OS updates on agents..."
# Add agent update verification
```

#### Monthly Security Review
```bash
#!/bin/bash
# monthly_security_review.sh

# 1. Password policy review
# 2. User access audit
# 3. Plugin security assessment
# 4. Network security verification
# 5. Backup security validation
```

### 7. Incident Response

#### Security Incident Playbook
1. **Detection**: Monitor alerts and logs
2. **Isolation**: Disable affected accounts/services
3. **Assessment**: Determine scope and impact
4. **Containment**: Implement temporary fixes
5. **Recovery**: Restore secure operations
6. **Lessons Learned**: Update security measures

#### Emergency Procedures
```bash
# Emergency shutdown
gcloud run services update jenkins-controller \
    --region=asia-east1 --max-instances=0

# Rotate secrets
gcloud secrets versions add jenkins-admin-password \
    --data-file=new_password.txt

# Review access logs
gcloud logging read "resource.type=cloud_run_revision" \
    --freshness=24h --format="table(timestamp,jsonPayload)"
```

### 8. Compliance and Documentation

#### Security Documentation
- Maintain security configuration documentation
- Document all changes and updates
- Keep incident response logs
- Regular security assessment reports

#### Compliance Checks
```yaml
# Automated compliance checking
compliance_checks:
  - password_policy: enabled
  - two_factor_auth: recommended
  - plugin_updates: automated
  - access_logging: enabled
  - backup_encryption: enabled
  - network_isolation: enforced
```

## Security Best Practices Summary

### ✅ Do's
- Use strong, unique passwords
- Enable all available security features
- Monitor logs regularly
- Keep plugins updated
- Use least privilege access
- Encrypt all data
- Regular security reviews
- Document security procedures

### ❌ Don'ts
- Don't use default passwords
- Don't install unnecessary plugins
- Don't grant excessive permissions
- Don't ignore security alerts
- Don't skip security updates
- Don't expose services publicly
- Don't store secrets in code
- Don't skip backup verification

### 🚨 Red Flags
- Multiple failed login attempts
- Unusual access patterns
- Plugin installation by non-admins
- Unexpected network connections
- Configuration changes outside maintenance windows
- High resource usage without corresponding jobs

Remember: Security is an ongoing process, not a one-time setup. Regular monitoring, updates, and reviews are essential for maintaining a secure Jenkins environment.
