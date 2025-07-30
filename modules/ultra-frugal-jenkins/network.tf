# Ultra-Frugal Jenkins Infrastructure - IAP-based Access
# This replaces the VPN-based network.tf with Identity-Aware Proxy

# Simplified VPC for Cloud Run and Spot VMs
resource "google_compute_network" "jenkins_vpc" {
  name                    = "jenkins-ultra-frugal-vpc"
  auto_create_subnetworks = false
  
  depends_on = [google_project_service.required_apis]
}

# Minimal subnet for cost optimization
resource "google_compute_subnetwork" "jenkins_subnet" {
  name          = "jenkins-frugal-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.jenkins_vpc.id
  
  # Enable private Google access for serverless services
  private_ip_google_access = true
}

# Serverless VPC Connector (minimal configuration for cost)
resource "google_vpc_access_connector" "jenkins_connector" {
  provider = google-beta
  name     = "jenkins-ultra-connector"
  region   = var.region
  
  subnet {
    name = google_compute_subnetwork.jenkins_subnet.name
  }
  
  # Ultra-minimal sizing for cost optimization
  machine_type   = "f1-micro"
  min_instances  = 2
  max_instances  = 3
}

# Firewall rule for IAP access (replaces VPN rules)
resource "google_compute_firewall" "allow_iap" {
  name    = "jenkins-allow-iap"
  network = google_compute_network.jenkins_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["8080", "22", "80", "443"]
  }
  
  # Google IAP source ranges
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["jenkins", "iap-access"]
}

# Firewall rule for internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "jenkins-allow-internal"
  network = google_compute_network.jenkins_vpc.name
  
  allow {
    protocol = "tcp"
  }
  
  allow {
    protocol = "udp"
  }
  
  allow {
    protocol = "icmp"
  }
  
  source_ranges = ["10.0.0.0/24"]
  target_tags   = ["jenkins"]
}

# Firewall rule for spot VM agents to reach internet (for downloads)
resource "google_compute_firewall" "allow_egress" {
  name      = "jenkins-allow-egress"
  network   = google_compute_network.jenkins_vpc.name
  direction = "EGRESS"
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
  }
  
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["jenkins-agent"]
}
