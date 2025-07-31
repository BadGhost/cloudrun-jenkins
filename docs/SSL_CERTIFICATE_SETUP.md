# SSL Certificate Setup with nip.io Domains

## Overview

This document explains the SSL certificate setup process for Ultra-Frugal Jenkins using nip.io domains and the fixes applied based on [this Medium article](https://medium.com/@jaredhatfield/simplify-gcp-load-balancer-prototyping-automatic-domains-certs-with-nip-io-1cf6cfafca02).

## The nip.io Domain Solution

### What is nip.io?

[nip.io](https://nip.io/) is a DNS service that provides automatic domain names for any IPv4 address. This eliminates the need to:
- Purchase and configure custom domains
- Set up DNS records manually
- Wait for DNS propagation

### Domain Format

The correct format for nip.io domains in GCP is:
```
jenkins-<IP-with-dashes>.nip.io
```

For example, if your static IP is `34.8.123.99`, the domain becomes:
```
jenkins-34-8-123-99.nip.io
```

## The Original Problem

### Incorrect Domain Format

Originally, the configuration used:
```terraform
domains = ["${google_compute_global_address.jenkins_ip.address}.nip.io"]
```

This created domains like `34.8.123.99.nip.io` which caused SSL certificate provisioning issues.

### Issues Caused

1. **SSL Certificate Failures**: GCP couldn't properly validate domains with dots in the subdomain
2. **IAP Authentication Problems**: Load balancer routing issues
3. **Inconsistent Domain References**: Different resources used different formats

## The Fix Applied

### 1. Local Variable for Domain Construction

Added a `locals` block in `cloudrun.tf`:

```terraform
locals {
  # Construct the nip.io domain with dashes instead of dots for proper SSL cert handling
  jenkins_domain = "jenkins-${replace(google_compute_global_address.jenkins_ip.address, ".", "-")}.nip.io"
}
```

### 2. Updated All Domain References

**SSL Certificate**:
```terraform
resource "google_compute_managed_ssl_certificate" "jenkins_ssl" {
  name = "jenkins-ultra-ssl-v3"
  
  managed {
    domains = [
      local.jenkins_domain  # Changed from direct IP reference
    ]
  }
}
```

**Load Balancer Host Rules**:
```terraform
host_rule {
  hosts        = [local.jenkins_domain]  # Changed from direct IP reference
  path_matcher = "jenkins-matcher"
}
```

**Jenkins Configuration Template**:
```terraform
templatefile("${path.module}/config/jenkins-ultra-frugal.yaml", {
  # ... other variables
  jenkins_domain = local.jenkins_domain  # Added new variable
})
```

**Jenkins Config File** (`jenkins-ultra-frugal.yaml`):
```yaml
unclassified:
  location:
    url: "https://${jenkins_domain}/jenkins"  # Changed from project_id based URL
```

### 3. Updated Outputs

All output URLs now use the consistent domain format:

```terraform
output "jenkins_url" {
  value = "https://${local.jenkins_domain}/jenkins"
}
```

## SSL Certificate Monitoring

### Automatic Monitoring Script

The `wait-ssl-cert.sh` script monitors SSL certificate provisioning:

```bash
#!/bin/bash
CERT_NAME="jenkins-ultra-ssl-v3"
MAX_WAIT_TIME=600  # 10 minutes

while true; do
    STATUS=$(gcloud compute ssl-certificates describe $CERT_NAME --global --format="value(managed.status)")
    
    if [ "$STATUS" = "ACTIVE" ]; then
        echo "🎉 SUCCESS! SSL certificate is now ACTIVE"
        exit 0
    fi
    
    sleep 30
done
```

### Manual Status Check

Check certificate status:
```bash
gcloud compute ssl-certificates describe jenkins-ultra-ssl-v3 --global --format="value(managed.status)"
```

Expected progression:
1. `PROVISIONING` → Takes 5-10 minutes
2. `ACTIVE` → Ready to use

## Deployment Process

### 1. Apply Terraform Changes

```bash
cd environments/dev
terraform plan
terraform apply -auto-approve
```

### 2. Monitor SSL Certificate

```bash
./wait-ssl-cert.sh
```

Or manually:
```bash
watch gcloud compute ssl-certificates describe jenkins-ultra-ssl-v3 --global --format="value(managed.status)"
```

### 3. Access Jenkins

Once SSL certificate is `ACTIVE`:
```
https://jenkins-34-8-123-99.nip.io/jenkins
```

## Troubleshooting

### SSL Certificate Stuck in PROVISIONING

**Cause**: Load balancer not properly configured or domain format incorrect

**Solution**:
1. Verify domain format uses dashes: `jenkins-X-X-X-X.nip.io`
2. Check load balancer configuration
3. Wait up to 10 minutes (normal for initial provisioning)

### SSL Certificate Shows ERROR

**Cause**: Domain validation failed

**Solution**:
```bash
# Check detailed certificate status
gcloud compute ssl-certificates describe jenkins-ultra-ssl-v3 --global

# Verify load balancer is serving traffic
curl -I https://jenkins-34-8-123-99.nip.io/jenkins
```

### Circular Dependency Error

**Cause**: SSL certificate depends on resources that depend on it

**Solution**: Already fixed by removing circular dependencies in the Terraform configuration.

## Benefits of This Implementation

### 1. Cost Optimization
- ✅ No domain purchase required
- ✅ No DNS hosting costs
- ✅ Automatic SSL certificate provisioning

### 2. Simplicity
- ✅ No manual DNS configuration
- ✅ Works immediately after deployment
- ✅ Perfect for prototyping and development

### 3. Security
- ✅ Full HTTPS encryption
- ✅ Automatic certificate renewal
- ✅ Integration with IAP for authentication

## References

- [Medium Article: Simplify GCP Load Balancer Prototyping with nip.io](https://medium.com/@jaredhatfield/simplify-gcp-load-balancer-prototyping-automatic-domains-certs-with-nip-io-1cf6cfafca02)
- [nip.io Documentation](https://nip.io/)
- [GCP Managed SSL Certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
