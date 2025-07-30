# Environment-specific variables for prod environment

variable "project_id" {
  description = "GCP Project ID for production"
  type        = string
}

variable "region" {
  description = "GCP Region - us-central1 for maximum cost efficiency"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone - us-central1-a for spot VM availability"
  type        = string
  default     = "us-central1-a"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
}

variable "jenkins_user_password" {
  description = "Jenkins second user password"
  type        = string
  sensitive   = true
}

variable "authorized_users" {
  description = "List of Google account emails authorized to access Jenkins"
  type        = list(string)
  validation {
    condition     = length(var.authorized_users) <= 3 && length(var.authorized_users) > 0
    error_message = "You can specify 1-3 authorized users for cost optimization."
  }
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    environment = "prod"
    project     = "ultra-frugal-jenkins"
    cost-center = "production"
  }
}
