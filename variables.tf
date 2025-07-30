# Required variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-east1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-east1-a"
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

variable "vpn_shared_secret" {
  description = "VPN shared secret for authentication"
  type        = string
  sensitive   = true
}

variable "client_ip_range" {
  description = "Your home IP range for VPN access (CIDR format)"
  type        = string
  default     = "192.168.1.0/24"
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
