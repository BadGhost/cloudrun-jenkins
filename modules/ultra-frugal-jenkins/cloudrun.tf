# Ultra-Frugal Cloud Run Jenkins 
# Personal projects don't support IAP, so we'll use IP-based security

# Locals for domain construction (following nip.io best practices)
locals {
  # Construct the nip.io domain with dashes instead of dots for proper SSL cert handling
  jenkins_domain = "jenkins-${replace(google_compute_global_address.jenkins_ip.address, ".", "-")}.nip.io"
}

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
      
      env {
        name  = "JENKINS_STORAGE_BUCKET"
        value = google_storage_bucket.jenkins_storage.name
      }
      
      env {
        name  = "JENKINS_HOME"
        value = "/var/jenkins_home"
      }
      
      # Selective GCS mounting for persistence (avoid mounting entire jenkins_home)
      volume_mounts {
        name       = "jenkins-jobs"
        mount_path = "/var/jenkins_home/jobs"
      }
      
      volume_mounts {
        name       = "jenkins-workspace"
        mount_path = "/var/jenkins_home/workspace"
      }
      
      volume_mounts {
        name       = "jenkins-users"
        mount_path = "/var/jenkins_home/users"
      }
      
      volume_mounts {
        name       = "jenkins-config"
        mount_path = "/var/jenkins_config"
      }
      
      # TCP-based startup probe (just checks if port is open, not if Jenkins is fully ready)
      startup_probe {
        tcp_socket {
          port = 8080
        }
        initial_delay_seconds = 90   # Allow time for GCS mounting + basic startup
        timeout_seconds       = 10   
        failure_threshold     = 20   # Many retries for first-time initialization
        period_seconds        = 15   
      }

      liveness_probe {
        http_get {
          path = "/jenkins/login"
          port = 8080
        }
        initial_delay_seconds = 120  # Wait for Jenkins to fully start
        timeout_seconds       = 10   # More forgiving timeout
        failure_threshold     = 5    # More retries before restart
        period_seconds        = 60   # Less frequent checks once running
      }
    }
    
    # Selective GCS mounting volumes for persistence (avoid mounting entire jenkins_home)
    volumes {
      name = "jenkins-jobs"
      gcs {
        bucket    = google_storage_bucket.jenkins_storage.name
        read_only = false
      }
    }

    volumes {
      name = "jenkins-workspace"
      gcs {
        bucket    = google_storage_bucket.jenkins_storage.name
        read_only = false
      }
    }

    volumes {
      name = "jenkins-users"
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
    }    # Service account
    service_account = google_service_account.jenkins_sa.email
    
    # VPC connector for spot VM communication
    vpc_access {
      connector = google_vpc_access_connector.jenkins_connector.id
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
  
  depends_on = [google_project_service.required_apis]
}

# Backend service for IAP
resource "google_compute_backend_service" "jenkins_backend" {
  name        = "jenkins-ultra-backend"
  description = "Backend service for ultra-frugal Jenkins"
  
  backend {
    group = google_compute_region_network_endpoint_group.jenkins_neg.id
  }
  
  # Timeout configuration
  timeout_sec = 30
  
  # Session affinity for Jenkins
  session_affinity = "CLIENT_IP"
}

# Configure IAP for the backend service
resource "google_iap_web_backend_service_iam_binding" "jenkins_iap_backend" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.jenkins_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = [for email in var.authorized_users : "user:${email}"]
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

# Allow unauthenticated access to Cloud Run for load balancer
resource "google_cloud_run_service_iam_member" "noauth" {
  location = google_cloud_run_v2_service.jenkins.location
  project  = google_cloud_run_v2_service.jenkins.project
  service  = google_cloud_run_v2_service.jenkins.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# OAuth client for IAP - Disabled for personal projects
# Personal Google Cloud projects don't support IAP brands
# Users will access Jenkins directly via Cloud Run URL

# resource "google_iap_brand" "jenkins_brand" {
#   support_email     = var.authorized_users[0]
#   application_title = "Ultra-Frugal Jenkins CI/CD"
#   project           = var.project_id
#   
#   depends_on = [google_project_service.required_apis]
# }

# resource "google_iap_client" "jenkins_oauth" {
#   display_name = "Jenkins Ultra-Frugal IAP Client"
#   brand        = google_iap_brand.jenkins_brand.name
# }

# Load balancer for IAP (minimal configuration)
resource "google_compute_url_map" "jenkins_lb" {
  name            = "jenkins-ultra-lb"
  description     = "Ultra-frugal load balancer for Jenkins IAP"
  default_service = google_compute_backend_service.jenkins_backend.id

  host_rule {
    hosts        = [local.jenkins_domain]
    path_matcher = "jenkins-matcher"
  }

  path_matcher {
    name            = "jenkins-matcher"
    default_service = google_compute_backend_service.jenkins_backend.id
    
    path_rule {
      paths   = ["/jenkins/*", "/jenkins"]
      service = google_compute_backend_service.jenkins_backend.id
    }
  }
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

# HTTP to HTTPS redirect
resource "google_compute_url_map" "jenkins_http_redirect" {
  name = "jenkins-http-redirect"
  
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "jenkins_http_proxy" {
  name    = "jenkins-http-proxy"
  url_map = google_compute_url_map.jenkins_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "jenkins_http_forwarding" {
  name       = "jenkins-http-forwarding"
  target     = google_compute_target_http_proxy.jenkins_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.jenkins_ip.address
}

# Static IP for the load balancer
resource "google_compute_global_address" "jenkins_ip" {
  name = "jenkins-ultra-ip"
  
  depends_on = [google_project_service.required_apis]
}

# Managed SSL certificate
resource "google_compute_managed_ssl_certificate" "jenkins_ssl" {
  name = "jenkins-ultra-ssl-v3"
  
  managed {
    domains = [
      local.jenkins_domain
    ]
  }
  
  depends_on = [google_project_service.required_apis]
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
  
  depends_on = [google_project_service.required_apis]
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
    jenkins_domain    = local.jenkins_domain
  })
}
