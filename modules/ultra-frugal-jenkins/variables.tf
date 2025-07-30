# Required variables
variable "project_id" {
  description = "GCP Project ID"
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
  default     = []
  validation {
    condition     = length(var.authorized_users) <= 3 && length(var.authorized_users) > 0
    error_message = "You can specify 1-3 authorized users for cost optimization."
  }
}

variable "vpn_shared_secret" {
  description = "VPN shared secret for authentication - DEPRECATED: Using IAP instead"
  type        = string
  sensitive   = true
  default     = ""
}

variable "client_ip_range" {
  description = "Your home IP range for VPN access - DEPRECATED: Using IAP instead"
  type        = string
  default     = ""
}

# Optional variables with defaults
variable "jenkins_version" {
  description = "Jenkins version to deploy"
  type        = string
  default     = "lts"
}

variable "jenkins_memory" {
  description = "Memory allocation for Jenkins Cloud Run"
  type        = string
  default     = "2Gi"
}

variable "jenkins_cpu" {
  description = "CPU allocation for Jenkins Cloud Run"
  type        = string
  default     = "1"
}

variable "storage_size" {
  description = "Size of persistent disk for Jenkins data (GB)"
  type        = number
  default     = 10
}

variable "max_agents" {
  description = "Maximum number of Jenkins agents"
  type        = number
  default     = 3
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    environment = "development"
    project     = "jenkins"
    cost-center = "personal"
  }
}
