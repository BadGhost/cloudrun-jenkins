# Copilot Instructions for Ultra-Frugal Jenkins on GCP

## Project Architecture

This is an "Ultra-Frugal" Jenkins deployment on Google Cloud Platform designed for **under $1.50/month** operation using:
- **Cloud Run** for Jenkins controller (scales to zero when idle)
- **Spot VMs** for build agents (91% cost savings) 
- **IP-based Security** or **Identity-Aware Proxy (IAP)** for secure access
- **Direct GCS mounting** replacing persistent disks entirely (zero storage costs)
- **nip.io domains** for automatic SSL certificate handling

## Critical Persistence Issue (ACTIVE)

**PROBLEM**: The current selective GCS mounting configuration in `cloudrun.tf` only mounts specific directories (`/var/jenkins_home/jobs`, `/var/jenkins_home/users`, `/var/jenkins_home/workspace`) but misses **critical Jenkins directories** like `/var/jenkins_home/secrets` (containing initial admin passwords) and the root `config.xml` file.

**SYMPTOM**: Jenkins shows initial setup screen every time instead of using configured credentials.

**ROOT CAUSE**: Jenkins core configuration files are not persisted between container restarts.

**SOLUTION PATTERNS**:
1. **Full Home Mounting**: Mount entire `/var/jenkins_home` to GCS for complete persistence
2. **Enhanced Selective Mounting**: Add missing directories like `secrets`, `userContent`, `fingerprints`
3. **Performance vs. Persistence Trade-off**: Balance cold start speed with data preservation

### Current vs. Fixed Configuration
```hcl
# BROKEN (current) - selective mounting missing critical paths
volume_mounts {
  name       = "jenkins-jobs"
  mount_path = "/var/jenkins_home/jobs"
}
# Missing: /var/jenkins_home/secrets, /var/jenkins_home/*.xml

# FIXED - complete persistence
volume_mounts {
  name       = "jenkins-home"
  mount_path = "/var/jenkins_home"  # Mount entire home directory
}
```

## Key Terraform Patterns

### Module Structure
- **Core module**: `modules/ultra-frugal-jenkins/` - Reusable infrastructure components
- **Environment configs**: `environments/{dev,prod}/` - Environment-specific instantiations
- **Separation**: Module contains ALL resources, environments only configure variables

### File Organization by Concern
- `main.tf` - API enablement only
- `cloudrun.tf` - Jenkins controller with nip.io domain + ultra-minimal resources
- `compute.tf` - Spot VM templates and managed instance groups
- `network.tf` - VPC, networking infrastructure
- `storage.tf` - GCS buckets replacing persistent disks, IAM service accounts
- `ip-security.tf` - IP allowlisting as IAP alternative for cost optimization

### Cost Optimization Patterns
- **Zero scaling**: Cloud Run `min_instance_count = 0` (true serverless)
- **Spot VMs**: `preemptible = true, provisioning_model = "SPOT"`
- **Minimal resources**: `e2-micro` instances, `1Gi` memory limits, `--prefix=/jenkins`
- **Regional deployment**: Default `us-central1` for lowest costs
- **GCS lifecycle**: Aggressive transitions to NEARLINE→COLDLINE→DELETE for storage savings
- **nip.io domains**: Automatic SSL without certificate management costs

## Security Models

### IP-Based Security (Default - Ultra-Frugal)
- **Automatic IP detection**: `data.http.current_ip` gets your public IP
- **Setup script**: `./setup-ip-security.sh` for interactive configuration
- **Firewall rules**: `ip-security.tf` manages IP allowlisting
- **Cost**: $0 (vs IAP's potential costs for large teams)

### Identity-Aware Proxy (IAP) Alternative  
- **User limit**: Validation restricts to 1-3 authorized users for cost control
- **No VPN needed**: Direct Google SSO integration
- **Enterprise-ready**: But adds complexity and potential costs

## Critical Jenkins Workflows

### Initial Setup Recovery (Common Issue)
When Jenkins shows setup wizard instead of configured credentials:
```bash
# Get auto-generated initial password from logs
gcloud run services logs read jenkins-ultra-frugal --region=us-central1 --limit=200 | grep -A2 "following password"

# Alternative: Use automated script
./environments/dev/get-jenkins-password.sh
```

**Pattern**: Jenkins generates temporary admin password on first startup, Configuration as Code (JCasC) loads AFTER initial unlock.

### Persistence Verification
```bash
# Test persistence after fixing mount configuration
./scripts/verify-persistence.sh YOUR_PROJECT_ID

# Manual test pattern:
# 1. Create test job → 2. Scale to zero → 3. Wait → 4. Scale up → 5. Verify job exists
```

## Deployment Workflows

### Dual Script Pattern
Both `deploy.ps1` (PowerShell) and `deploy.sh` (Bash) provide identical functionality:
- Prerequisite validation (gcloud auth, terraform version, project access)
- Cost estimation display before deployment
- Environment-aware Terraform operations
- Comprehensive error handling and user guidance

### Environment Management
```bash
# Development (local state)
./deploy.sh dev

# Production (GCS backend)
./deploy.sh prod
```

Key difference: Production uses GCS backend in `backend.tf`, dev uses local state.

## Configuration Patterns

### Variable Validation
Critical cost control through Terraform validation:
```hcl
validation {
  condition     = length(var.authorized_users) <= 3 && length(var.authorized_users) > 0
  error_message = "You can specify 1-3 authorized users for cost optimization."
}
```

### Jenkins Configuration as Code (JCasC)
- Template files in `modules/ultra-frugal-jenkins/config/`
- Variables injected via Terraform: `${admin_password}`, `${project_id}`
- **Local security realm** (not IAP-integrated) in ultra-frugal config
- **Critical**: Loads AFTER initial setup wizard completion

### Domain Construction Pattern
```hcl
# nip.io domain with IP-to-domain mapping for SSL
jenkins_domain = "jenkins-${replace(google_compute_global_address.jenkins_ip.address, ".", "-")}.nip.io"
```

## Essential Utility Scripts

### Password Retrieval
```bash
# Get initial Jenkins admin password from Cloud Run logs
./environments/dev/get-jenkins-password.sh
```

### IP Security Setup
```bash
# Interactive setup for IP allowlisting (IAP alternative)
./setup-ip-security.sh
```

### Persistence Testing
```bash
# Verify GCS mounting works correctly
./scripts/verify-persistence.sh PROJECT_ID
```

### Jenkins Access
After deployment, access via: `https://jenkins-[IP-with-dashes].nip.io/jenkins`

## Performance Characteristics

### Cold Start Impact
- **With selective mounting**: ~45-60 seconds (only jobs/users/workspace)
- **With full home mounting**: ~60-90 seconds (complete JENKINS_HOME)
- **Trade-off**: Complete persistence vs. faster cold starts

### GCS Mount Performance
- **FUSE-based mounting**: Direct file system access to GCS
- **Caching**: 60-second TTL by default, configurable via mount options
- **Write staging**: Files staged in memory before GCS upload

## Critical Dependencies

### Required GCP APIs
Always enabled in `main.tf`:
```
compute.googleapis.com, run.googleapis.com, storage.googleapis.com,
container.googleapis.com, iam.googleapis.com, cloudbuild.googleapis.com,
secretmanager.googleapis.com, iap.googleapis.com
```

### Cloud Run Gen2 Requirements
- **Execution environment**: `EXECUTION_ENVIRONMENT_GEN2` required for GCS volume mounting
- **Memory considerations**: GCS FUSE uses container memory for caching and file staging
- **Mount options**: Available for tuning cache behavior and performance

## Development Guidelines

### When Fixing Persistence Issues
1. **Identify missing paths**: Check which Jenkins directories aren't persisted
2. **Choose mounting strategy**: Full `/var/jenkins_home` vs. selective directories + missing paths
3. **Test cold starts**: Verify performance impact after changes
4. **Update verification scripts**: Ensure `verify-persistence.sh` tests critical paths

### When Modifying Costs
- Update cost estimates in both deployment scripts
- Modify validation rules in `variables.tf`
- Test in dev environment first

### Terraform State Management
- **Dev**: Local state for rapid iteration
- **Prod**: GCS backend for team collaboration
- Never mix state backends between environments

The "ultra-frugal" philosophy drives all architectural decisions - prioritize cost optimization while maintaining enterprise security and now ensuring complete data persistence through proper GCS mounting configuration.
