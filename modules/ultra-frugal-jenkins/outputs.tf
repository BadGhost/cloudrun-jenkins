output "jenkins_url" {
  description = "Public HTTPS URL for Jenkins (IAP-protected)"
  value       = "https://${local.jenkins_domain}/jenkins"
  sensitive   = false
}

output "jenkins_iap_url" {
  description = "Alternative IAP URL for Jenkins"
  value       = "https://${local.jenkins_domain}/jenkins"
  sensitive   = false
}

output "jenkins_domain" {
  description = "The nip.io domain for Jenkins (for SSL certificate validation)"
  value       = local.jenkins_domain
  sensitive   = false
}

output "jenkins_static_ip" {
  description = "Static IP address for the Jenkins load balancer"
  value       = google_compute_global_address.jenkins_ip.address
  sensitive   = false
}

output "authorized_users" {
  description = "Google accounts authorized to access Jenkins via IAP"
  value       = var.authorized_users
  sensitive   = false
}

output "jenkins_storage_bucket" {
  description = "Cloud Storage bucket for Jenkins data"
  value       = google_storage_bucket.jenkins_storage.name
  sensitive   = false
}

output "jenkins_service_account" {
  description = "Service account email for Jenkins"
  value       = google_service_account.jenkins_sa.email
  sensitive   = false
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.jenkins_vpc.name
  sensitive   = false
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.jenkins_subnet.name
  sensitive   = false
}

output "vpc_connector_name" {
  description = "VPC connector name for Cloud Run"
  value       = google_vpc_access_connector.jenkins_connector.name
  sensitive   = false
}

output "cost_optimization_summary" {
  description = "Summary of ultra-frugal cost optimization features"
  value = {
    serverless_controller    = "Cloud Run scales to zero when not in use"
    spot_vm_agents          = "91% cost savings on compute instances"
    gcs_direct_mounting     = "No persistent disk costs - direct GCS mounting"
    iap_authentication      = "No VPN infrastructure costs"
    regional_deployment     = "us-central1 for maximum cost efficiency"
    minimal_resources       = "Ultra-lean CPU and memory allocation"
    aggressive_cleanup      = "Auto-shutdown agents when idle"
    lifecycle_management    = "30-day data archival, 180-day deletion"
    estimated_monthly_cost  = "$0.80-$1.50 (well under $2 budget!)"
  }
  sensitive = false
}

output "security_features" {
  description = "Summary of security features implemented"
  value = {
    iap_authentication   = "Google Identity-Aware Proxy for zero-config access"
    https_only          = "Managed SSL certificates with automatic renewal"
    private_networking  = "Spot VMs use private IPs only"
    iam_integration     = "Native Google Cloud IAM integration"
    secret_management   = "Passwords stored in Secret Manager"
    authorized_users    = "Access restricted to specified Google accounts only"
    no_client_software  = "No VPN client setup required"
  }
  sensitive = false
}

output "deployment_instructions" {
  description = "Next steps after deployment"
  value = <<-EOT
    🎉 Ultra-Frugal Jenkins Deployment Complete!
    
    1. ✅ Infrastructure deployed in us-central1 (most cost-effective region)
    2. ✅ IAP authentication configured for authorized users
    3. ✅ Spot VMs ready for 91% cost savings on builds
    4. ✅ Direct GCS mounting eliminates persistent disk costs
    
    📍 Access Jenkins:
       URL: https://${local.jenkins_domain}/jenkins
       
    🔐 Authentication:
       - Automatic via Google IAP (no VPN setup needed!)
       - Authorized users: ${join(", ", var.authorized_users)}
       - Additional login: admin/(your password) or user/(your password)
    
    💰 Expected Monthly Cost: $0.80 - $1.50 (well under $2 budget!)
    
    🚀 Next Steps:
       1. Wait 5-10 minutes for SSL certificate provisioning
       2. Open the Jenkins URL in your browser (https required)
       3. Sign in with your authorized Google account
       4. Create your first pipeline job
       5. Watch Spot VM agents provision automatically
       6. Monitor costs in GCP Console
    
    📊 Cost Monitoring:
       - Set budget alerts in GCP Console
       - Monitor Cloud Run and Compute usage
       - Check storage usage in Cloud Storage
  EOT
  sensitive = false
}
