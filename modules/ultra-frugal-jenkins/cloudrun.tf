# Ultra-Frugal Cloud Run Jenkins with IAP Authentication
# This replaces VPN-based access with Google Identity-Aware Proxy

# Cloud Run service for Jenkins controller (ultra-frugal configuration)
resource "google_cloud_run_v2_service" "jenkins" {
  name     = "jenkins-ultra-frugal"
  location = var.region
  
  template {
    # Ultra-aggressive scaling for maximum cost savings
    scaling {
      min_instance_count = 0  # Scale to zero when not in use
      max_instance_count = 1  # Only one instance ever needed
    }
    
    # Minimal resource allocation for cost optimization
    containers {
      image = "jenkins/jenkins:${var.jenkins_version}"
      
      resources {
        limits = {
          cpu    = "1"      # Minimal CPU
          memory = "1Gi"    # Minimal memory for cost savings
        }
        startup_cpu_boost = true  # Faster cold starts
      }
      
      ports {
        container_port = 8080
      }
      
      # Ultra-frugal environment variables
      env {
        name  = "JENKINS_OPTS"
        value = "--httpPort=8080 --prefix=/jenkins"  # Add prefix for IAP
      }
      
      env {
        name  = "JAVA_OPTS"
        value = "-Djava.awt.headless=true -Xmx768m -XX:+UseG1GC -XX:+UseContainerSupport -XX:MaxRAMPercentage=75"
      }
      
      env {
        name  = "CASC_JENKINS_CONFIG"
        value = "/var/jenkins_config/jenkins.yaml"
      }
      
      # Direct GCS mounting (your brilliant idea!)
      volume_mounts {
        name       = "jenkins-home"
        mount_path = "/var/jenkins_home"
      }
      
      volume_mounts {
        name       = "jenkins-config"
        mount_path = "/var/jenkins_config"
      }
      
      # Optimized health checks
      startup_probe {
        http_get {
          path = "/jenkins/login"
          port = 8080
        }
        initial_delay_seconds = 30  # Faster startup
        timeout_seconds       = 10
        failure_threshold     = 10
        period_seconds        = 5
      }
      
      liveness_probe {
        http_get {
          path = "/jenkins/login"
          port = 8080
        }
        initial_delay_seconds = 60
        timeout_seconds       = 5
        failure_threshold     = 3
        period_seconds        = 30
      }
    }
    
    # Direct GCS mounting volumes
    volumes {
      name = "jenkins-home"
      gcs {
        bucket    = google_storage_bucket.jenkins_storage.name
        read_only = false
      }
    }
    
    volumes {
      name = "jenkins-config"
      secret {
        secret       = google_secret_manager_secret.jenkins_config.secret_id
        default_mode = 420
        items {
          version = "latest"
          path    = "jenkins.yaml"
        }
      }
    }
    
    # Service account
    service_account = google_service_account.jenkins_sa.email
    
    # VPC connector for spot VM communication
    vpc_access {
      connector = google_vpc_access_connector.jenkins_connector.name
      egress    = "PRIVATE_RANGES_ONLY"
    }
    
    # Execution environment
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    
    # Timeout for cost optimization
    timeout = "300s"  # 5-minute timeout
  }
  
  # Traffic configuration
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
  
  labels = merge(var.labels, {
    cost-optimization = "ultra-frugal"
    access-method     = "iap"
  })
  
  depends_on = [
    google_vpc_access_connector.jenkins_connector,
    google_secret_manager_secret_version.jenkins_config
  ]
}

# Identity-Aware Proxy configuration (replaces VPN!)
resource "google_iap_web_type_compute_iam_binding" "jenkins_iap" {
  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  members = [for email in var.authorized_users : "user:${email}"]
}

# Backend service for IAP
resource "google_compute_backend_service" "jenkins_backend" {
  name        = "jenkins-ultra-backend"
  description = "Backend service for ultra-frugal Jenkins"
  
  backend {
    group = google_compute_region_network_endpoint_group.jenkins_neg.id
  }
  
  iap {
    enabled              = true
    oauth2_client_id     = google_iap_client.jenkins_oauth.client_id
    oauth2_client_secret = google_iap_client.jenkins_oauth.secret
  }
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "jenkins_neg" {
  name                  = "jenkins-ultra-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  
  cloud_run {
    service = google_cloud_run_v2_service.jenkins.name
  }
}

# OAuth client for IAP
resource "google_iap_client" "jenkins_oauth" {
  display_name = "Jenkins Ultra-Frugal IAP Client"
  brand        = google_iap_brand.jenkins_brand.name
}

# IAP brand configuration
resource "google_iap_brand" "jenkins_brand" {
  support_email     = var.authorized_users[0]  # First user as support contact
  application_title = "Ultra-Frugal Jenkins CI/CD"
  project           = var.project_id
}

# Load balancer for IAP (minimal configuration)
resource "google_compute_url_map" "jenkins_lb" {
  name            = "jenkins-ultra-lb"
  description     = "Ultra-frugal load balancer for Jenkins IAP"
  default_service = google_compute_backend_service.jenkins_backend.id
}

resource "google_compute_target_https_proxy" "jenkins_proxy" {
  name             = "jenkins-ultra-proxy"
  url_map          = google_compute_url_map.jenkins_lb.id
  ssl_certificates = [google_compute_managed_ssl_certificate.jenkins_ssl.id]
}

resource "google_compute_global_forwarding_rule" "jenkins_forwarding" {
  name       = "jenkins-ultra-forwarding"
  target     = google_compute_target_https_proxy.jenkins_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.jenkins_ip.address
}

# Static IP for the load balancer
resource "google_compute_global_address" "jenkins_ip" {
  name = "jenkins-ultra-ip"
}

# Managed SSL certificate
resource "google_compute_managed_ssl_certificate" "jenkins_ssl" {
  name = "jenkins-ultra-ssl"
  
  managed {
    domains = ["jenkins-${var.project_id}.nip.io"]  # Free domain service
  }
}

# Secret for Jenkins configuration as code (updated for IAP)
resource "google_secret_manager_secret" "jenkins_config" {
  secret_id = "jenkins-ultra-config"
  
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "jenkins_config" {
  secret = google_secret_manager_secret.jenkins_config.id
  secret_data = templatefile("${path.module}/config/jenkins-ultra-frugal.yaml", {
    admin_password    = var.jenkins_admin_password
    user_password     = var.jenkins_user_password
    project_id        = var.project_id
    region            = var.region
    zone              = var.zone
    network           = google_compute_network.jenkins_vpc.name
    subnetwork        = google_compute_subnetwork.jenkins_subnet.name
    authorized_users  = var.authorized_users
    storage_bucket    = google_storage_bucket.jenkins_storage.name
  })
}
