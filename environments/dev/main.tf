# Dev environment main configuration
# This instantiates the ultra-frugal-jenkins module

module "ultra_frugal_jenkins" {
  source = "../../modules/ultra-frugal-jenkins"
  
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
  
  jenkins_admin_password = var.jenkins_admin_password
  jenkins_user_password  = var.jenkins_user_password
  
  authorized_users = var.authorized_users
  additional_allowed_ips = var.additional_allowed_ips
  
  labels = var.labels
}
