# Create VPC network
resource "google_compute_network" "jenkins_vpc" {
  name                    = "jenkins-vpc"
  auto_create_subnetworks = false
  
  depends_on = [google_project_service.required_apis]
}

# Create subnet
resource "google_compute_subnetwork" "jenkins_subnet" {
  name          = "jenkins-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.jenkins_vpc.id
  
  # Enable private Google access for Cloud Run
  private_ip_google_access = true
}

# Create VPN Gateway
resource "google_compute_vpn_gateway" "jenkins_vpn_gateway" {
  name    = "jenkins-vpn-gateway"
  network = google_compute_network.jenkins_vpc.id
  region  = var.region
}

# Reserve static IP for VPN
resource "google_compute_address" "vpn_ip" {
  name   = "jenkins-vpn-ip"
  region = var.region
}

# Create VPN tunnel
resource "google_compute_vpn_tunnel" "jenkins_vpn_tunnel" {
  name          = "jenkins-vpn-tunnel"
  peer_ip       = "YOUR_HOME_PUBLIC_IP" # You'll need to update this manually
  shared_secret = var.vpn_shared_secret
  
  target_vpn_gateway = google_compute_vpn_gateway.jenkins_vpn_gateway.id
  
  local_traffic_selector  = ["0.0.0.0/0"]
  remote_traffic_selector = [var.client_ip_range]
  
  depends_on = [
    google_compute_forwarding_rule.esp,
    google_compute_forwarding_rule.udp500,
    google_compute_forwarding_rule.udp4500,
  ]
}

# VPN forwarding rules
resource "google_compute_forwarding_rule" "esp" {
  name        = "jenkins-vpn-esp"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_ip.address
  target      = google_compute_vpn_gateway.jenkins_vpn_gateway.id
  region      = var.region
}

resource "google_compute_forwarding_rule" "udp500" {
  name        = "jenkins-vpn-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_ip.address
  target      = google_compute_vpn_gateway.jenkins_vpn_gateway.id
  region      = var.region
}

resource "google_compute_forwarding_rule" "udp4500" {
  name        = "jenkins-vpn-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_ip.address
  target      = google_compute_vpn_gateway.jenkins_vpn_gateway.id
  region      = var.region
}

# VPN route
resource "google_compute_route" "jenkins_vpn_route" {
  name       = "jenkins-vpn-route"
  network    = google_compute_network.jenkins_vpc.name
  dest_range = var.client_ip_range
  priority   = 1000
  
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.jenkins_vpn_tunnel.id
}

# Firewall rule to allow VPN traffic
resource "google_compute_firewall" "allow_vpn" {
  name    = "jenkins-allow-vpn"
  network = google_compute_network.jenkins_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["8080", "22", "80", "443"]
  }
  
  allow {
    protocol = "icmp"
  }
  
  source_ranges = [var.client_ip_range]
  target_tags   = ["jenkins"]
}

# Firewall rule for Cloud Run connector
resource "google_compute_firewall" "allow_cloud_run_egress" {
  name    = "jenkins-allow-cloud-run-egress"
  network = google_compute_network.jenkins_vpc.name
  
  allow {
    protocol = "tcp"
  }
  
  direction     = "EGRESS"
  target_tags   = ["cloud-run-connector"]
  destination_ranges = ["0.0.0.0/0"]
}

# VPC Connector for Cloud Run
resource "google_vpc_access_connector" "jenkins_connector" {
  provider = google-beta
  name     = "jenkins-connector"
  region   = var.region
  
  subnet {
    name = google_compute_subnetwork.jenkins_subnet.name
  }
  
  machine_type   = "e2-micro"
  min_instances  = 2
  max_instances  = 3
}
