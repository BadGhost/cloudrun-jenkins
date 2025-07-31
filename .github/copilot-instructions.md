# Copilot Instructions for Ultra-Frugal Jenkins on GCP

## Project Architecture

This is an "Ultra-Frugal" Jenkins deployment on Google Cloud Platform designed for **under $1.50/month** operation using:
- **Cloud Run** for Jenkins controller (scales to zero when idle)
- **Spot VMs** for build agents (91% cost savings) 
- **IP-based Security** or **Identity-Aware Proxy (IAP)** for secure access
- **Direct GCS mounting** replacing persistent disks entirely (zero storage costs)
- **nip.io domains** for automatic SSL certificate handling

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
- IAP-optimized security realm configuration
- **Auto-mounting**: GCS buckets replace traditional persistent volumes

### Agent Startup Scripts
Located in `modules/ultra-frugal-jenkins/scripts/`:
- `agent-startup.sh` - Standard agent setup
- `spot-agent-startup.sh` - Optimized for Spot VMs with auto-termination

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

### Jenkins Access
After deployment, access via: `https://jenkins-[IP-with-dashes].nip.io/jenkins`

## Critical Dependencies

### Required GCP APIs
Always enabled in `main.tf`:
```
compute.googleapis.com, run.googleapis.com, storage.googleapis.com,
container.googleapis.com, iam.googleapis.com, cloudbuild.googleapis.com,
secretmanager.googleapis.com, iap.googleapis.com
```

### IP Security Authentication Flow
- **Current IP auto-detection**: Uses `https://ipinfo.io/ip` for automatic IP discovery
- **Additional IPs**: Configurable via `additional_allowed_ips` variable
- **Firewall rule**: `google_compute_firewall.jenkins_ip_allowlist` restricts access

### IAP Authentication Flow (Alternative)
- No VPN needed - all access through IAP
- Authorized users defined in `terraform.tfvars`
- Service accounts configured with minimal required permissions

## Development Guidelines

### When Modifying Costs
- Update cost estimates in both deployment scripts
- Modify validation rules in `variables.tf`
- Test in dev environment first

### Adding New Environments
1. Copy `environments/dev/` structure
2. Update `backend.tf` for state management
3. Customize `terraform.tfvars.example`

### Terraform State Management
- **Dev**: Local state for rapid iteration
- **Prod**: GCS backend for team collaboration
- Never mix state backends between environments

## Common Operations

### Deploy with validation skip
```bash
./deploy.sh dev --skip-validation --force
```

### Check costs after deployment
```bash
cd environments/dev && terraform output
```

### Destroy environment
```bash
./deploy.sh dev --destroy
```

### View agent status
```bash
gcloud compute instances list --filter='name:spot-agent*'
```

The "ultra-frugal" philosophy drives all architectural decisions - prioritize cost optimization while maintaining enterprise security through IAP and minimal viable resource allocation.
