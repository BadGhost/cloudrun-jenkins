output "jenkins_url" {
  description = "Internal URL for Jenkins controller"
  value       = google_cloud_run_v2_service.jenkins.uri
  sensitive   = false
}

output "vpn_gateway_ip" {
  description = "Public IP address of the VPN gateway"
  value       = google_compute_address.vpn_ip.address
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
  description = "Summary of cost optimization features"
  value = {
    serverless_controller = "Cloud Run scales to zero when not in use"
    preemptible_agents   = "90% cost savings on compute instances"
    storage_lifecycle    = "Automatic data archival after 90 days"
    regional_deployment  = "asia-east1 for cost optimization"
    resource_limits      = "CPU and memory limits enforced"
    auto_shutdown        = "Agents auto-terminate when idle"
  }
  sensitive = false
}

output "security_features" {
  description = "Summary of security features implemented"
  value = {
    private_networking = "VPN-only access, no public endpoints"
    iam_roles         = "Least privilege service accounts"
    secret_management = "Passwords stored in Secret Manager"
    network_policies  = "Firewall rules for restricted access"
    ssl_termination   = "HTTPS enforced on Cloud Run"
    user_management   = "Jenkins built-in user database"
  }
  sensitive = false
}

output "deployment_instructions" {
  description = "Next steps after deployment"
  value = <<-EOT
    1. Update YOUR_HOME_PUBLIC_IP in network.tf with your actual public IP
    2. Configure your VPN client with:
       - Gateway IP: ${google_compute_address.vpn_ip.address}
       - Shared Secret: (from terraform.tfvars)
       - Remote Network: 10.0.0.0/24
    3. Access Jenkins at: ${google_cloud_run_v2_service.jenkins.uri}
    4. Login with admin/(your password) or user/(your password)
    5. Configure Jenkins agents in Manage Jenkins > Manage Nodes and Clouds
  EOT
  sensitive = false
}
