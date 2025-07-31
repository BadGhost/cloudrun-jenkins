# IP-based Security for Ultra-Frugal Jenkins
# This provides IP allowlisting as an alternative to IAP

# Get current public IP automatically
data "http" "current_ip" {
  url = "https://ipinfo.io/ip"
}

locals {
  current_ip = chomp(data.http.current_ip.response_body)
  
  # Default IP allowlist includes current IP + any additional IPs
  default_allowed_ips = [
    "${local.current_ip}/32"
  ]
  
  # Combine with any additional IPs from variables
  allowed_ips = concat(
    local.default_allowed_ips,
    var.additional_allowed_ips
  )
}

# IP allowlist firewall rule
resource "google_compute_firewall" "jenkins_ip_allowlist" {
  name        = "jenkins-ip-allowlist"
  network     = google_compute_network.jenkins_vpc.name
  description = "Allow HTTPS access only from specific IP addresses"
  
  allow {
    protocol = "tcp"
    ports    = ["443", "80"]  # Allow both HTTP and HTTPS
  }
  
  source_ranges = local.allowed_ips
  target_tags   = ["jenkins", "iap-access"]
  priority      = 100
}

# Block all other HTTPS access with lower priority
resource "google_compute_firewall" "jenkins_block_others" {
  name        = "jenkins-block-others-https"
  network     = google_compute_network.jenkins_vpc.name
  description = "Block HTTPS access from all other IPs"
  
  deny {
    protocol = "tcp"
    ports    = ["443", "80"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins", "iap-access"]
  priority      = 200
}

# Output information about the security setup
output "ip_security_info" {
  description = "Information about IP-based security"
  value = {
    current_detected_ip = local.current_ip
    allowed_ips        = local.allowed_ips
    security_method    = "IP-based allowlisting"
    
    instructions = [
      "Your Jenkins is protected by IP allowlisting",
      "Current allowed IPs: ${join(", ", local.allowed_ips)}",
      "To add more IPs, update the 'additional_allowed_ips' variable",
      "When your IP changes, re-run terraform apply to update"
    ]
  }
}
