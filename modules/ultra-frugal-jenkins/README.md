# Ultra-Frugal Jenkins Module

This module deploys a cost-optimized Jenkins CI/CD system on Google Cloud Platform using serverless technologies and Spot VMs.

## Architecture

- **Jenkins Controller**: Cloud Run service that scales to zero
- **Build Agents**: Spot VM instances with 91% cost savings
- **Storage**: Direct Google Cloud Storage mounting
- **Access**: Google Identity-Aware Proxy (no VPN required)
- **Security**: Private networking with IAM integration

## Features

- ✅ Scales to zero when not in use
- ✅ 91% cost savings on compute with Spot VMs
- ✅ Direct GCS mounting (no persistent disk costs)
- ✅ Zero-config access via Google IAP
- ✅ Enterprise-grade security
- ✅ Automatic SSL certificates

## Usage

```hcl
module "ultra_frugal_jenkins" {
  source = "./modules/ultra-frugal-jenkins"
  
  project_id = var.project_id
  region     = var.region
  
  jenkins_admin_password = var.jenkins_admin_password
  jenkins_user_password  = var.jenkins_user_password
  
  authorized_users = var.authorized_users
  
  labels = var.labels
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | ~> 5.0 |
| google-beta | ~> 5.0 |
| random | ~> 3.4 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 5.0 |
| google-beta | ~> 5.0 |
| random | ~> 3.4 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP Project ID | `string` | n/a | yes |
| region | GCP Region | `string` | `"us-central1"` | no |
| jenkins_admin_password | Jenkins admin password | `string` | n/a | yes |
| jenkins_user_password | Jenkins second user password | `string` | n/a | yes |
| authorized_users | List of Google account emails authorized to access Jenkins | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| jenkins_url | Public HTTPS URL for Jenkins (IAP-protected) |
| jenkins_storage_bucket | Cloud Storage bucket for Jenkins data |
| jenkins_service_account | Service account email for Jenkins |
| cost_optimization_summary | Summary of cost optimization features |

## Estimated Monthly Costs

| Component | Cost Range | Notes |
|-----------|------------|-------|
| Cloud Run Controller | $0.00-$0.30 | Scales to zero when idle |
| Spot VM Agents | $0.20-$0.60 | 91% discount on compute |
| Cloud Storage | $0.10-$0.25 | Pay for actual usage |
| Load Balancer | $0.20-$0.30 | IAP-enabled HTTPS |
| **Total** | **$0.50-$1.45** | **Under $1.50/month** |
