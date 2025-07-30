# Ultra-frugal instance template for Jenkins agents using Spot VMs (91% discount!)
resource "google_compute_instance_template" "jenkins_agent" {
  name_prefix  = "jenkins-spot-agent-"
  machine_type = "e2-micro"  # Smallest possible for maximum cost savings
  
  # Use Spot VMs for maximum 91% cost savings
  scheduling {
    preemptible                 = true
    automatic_restart           = false
    on_host_maintenance         = "TERMINATE"
    provisioning_model          = "SPOT"
    instance_termination_action = "STOP"
  }
  
  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10  # Minimal disk size for cost savings
    type         = "pd-standard"  # Cheapest disk type
  }
  
  network_interface {
    network    = google_compute_network.jenkins_vpc.name
    subnetwork = google_compute_subnetwork.jenkins_subnet.name
    
    # No external IP to save costs - agents communicate through internal network
    # access_config {}  # Commented out for private access only
  }
  
  service_account {
    email  = google_service_account.jenkins_sa.email
    scopes = ["cloud-platform"]
  }
  
  metadata = {
    enable-oslogin = "TRUE"
  }
  
  # Startup script to configure ultra-lean Jenkins agent
  metadata_startup_script = templatefile("${path.module}/scripts/spot-agent-startup.sh", {
    jenkins_url = google_cloud_run_v2_service.jenkins.uri
    project_id  = var.project_id
    zone        = var.zone
    bucket_name = google_storage_bucket.jenkins_storage.name
  })
  
  tags = ["jenkins", "jenkins-agent", "iap-access", "spot-vm"]
  
  labels = var.labels
  
  lifecycle {
    create_before_destroy = true
  }
}

# Managed instance group for Jenkins agents
resource "google_compute_region_instance_group_manager" "jenkins_agents" {
  name   = "jenkins-agents"
  region = var.region
  
  base_instance_name = "jenkins-agent"
  target_size        = 0  # Start with 0, Jenkins will scale up as needed
  
  version {
    instance_template = google_compute_instance_template.jenkins_agent.id
  }
  
  # Auto-healing policy
  auto_healing_policies {
    health_check      = google_compute_health_check.jenkins_agent.id
    initial_delay_sec = 300
  }
  
  # Update policy for rolling updates
  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 1
    max_unavailable_fixed        = 0
  }
}

# Health check for Jenkins agents
resource "google_compute_health_check" "jenkins_agent" {
  name               = "jenkins-agent-health-check"
  check_interval_sec = 30
  timeout_sec        = 10
  
  tcp_health_check {
    port = "22"  # SSH port for health checking
  }
}

# Autoscaler for Jenkins agents
resource "google_compute_region_autoscaler" "jenkins_agents" {
  name   = "jenkins-agents-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.jenkins_agents.id
  
  autoscaling_policy {
    max_replicas    = var.max_agents
    min_replicas    = 0
    cooldown_period = 300
    
    # Scale based on CPU utilization
    cpu_utilization {
      target = 0.8
    }
  }
}
