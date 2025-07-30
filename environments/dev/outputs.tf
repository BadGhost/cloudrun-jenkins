# Dev environment outputs
# These expose the module outputs at the root level

output "jenkins_url" {
  description = "Public HTTPS URL for Jenkins (IAP-protected)"
  value       = module.ultra_frugal_jenkins.jenkins_url
  sensitive   = false
}

output "jenkins_iap_url" {
  description = "Alternative IAP URL for Jenkins"
  value       = module.ultra_frugal_jenkins.jenkins_iap_url
  sensitive   = false
}

output "authorized_users" {
  description = "Google accounts authorized to access Jenkins via IAP"
  value       = module.ultra_frugal_jenkins.authorized_users
  sensitive   = false
}

output "jenkins_storage_bucket" {
  description = "Cloud Storage bucket for Jenkins data"
  value       = module.ultra_frugal_jenkins.jenkins_storage_bucket
  sensitive   = false
}

output "jenkins_service_account" {
  description = "Service account email for Jenkins"
  value       = module.ultra_frugal_jenkins.jenkins_service_account
  sensitive   = false
}

output "network_name" {
  description = "VPC network name"
  value       = module.ultra_frugal_jenkins.network_name
  sensitive   = false
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.ultra_frugal_jenkins.subnet_name
  sensitive   = false
}

output "vpc_connector_name" {
  description = "VPC connector name for Cloud Run"
  value       = module.ultra_frugal_jenkins.vpc_connector_name
  sensitive   = false
}

output "cost_optimization_summary" {
  description = "Summary of ultra-frugal cost optimization features"
  value       = module.ultra_frugal_jenkins.cost_optimization_summary
  sensitive   = false
}

output "security_features" {
  description = "Summary of security features implemented"
  value       = module.ultra_frugal_jenkins.security_features
  sensitive   = false
}

output "deployment_instructions" {
  description = "Next steps after deployment"
  value       = module.ultra_frugal_jenkins.deployment_instructions
  sensitive   = false
}

# Export the entire module for other configurations to reference
output "jenkins_module" {
  description = "The ultra-frugal Jenkins module outputs"
  value       = module.ultra_frugal_jenkins
  sensitive   = false
}
