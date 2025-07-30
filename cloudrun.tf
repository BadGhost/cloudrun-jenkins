# Cloud Run service for Jenkins controller
resource "google_cloud_run_v2_service" "jenkins" {
  name     = "jenkins-controller"
  location = var.region
  
  template {
    # Cost optimization: scale to zero when not in use
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
    
    # Resource limits for cost control
    containers {
      image = "jenkins/jenkins:${var.jenkins_version}"
      
      resources {
        limits = {
          cpu    = var.jenkins_cpu
          memory = var.jenkins_memory
        }
      }
      
      ports {
        container_port = 8080
      }
      
      # Environment variables
      env {
        name  = "JENKINS_OPTS"
        value = "--httpPort=8080"
      }
      
      env {
        name  = "JAVA_OPTS"
        value = "-Djava.awt.headless=true -Xmx1g -XX:+UseG1GC -XX:+UseContainerSupport"
      }
      
      env {
        name  = "CASC_JENKINS_CONFIG"
        value = "/var/jenkins_config/jenkins.yaml"
      }
      
      # Volume mounts
      volume_mounts {
        name       = "jenkins-home"
        mount_path = "/var/jenkins_home"
      }
      
      volume_mounts {
        name       = "jenkins-config"
        mount_path = "/var/jenkins_config"
      }
      
      # Startup probe
      startup_probe {
        http_get {
          path = "/login"
          port = 8080
        }
        initial_delay_seconds = 60
        timeout_seconds       = 30
        failure_threshold     = 10
        period_seconds        = 10
      }
      
      # Liveness probe
      liveness_probe {
        http_get {
          path = "/login"
          port = 8080
        }
        initial_delay_seconds = 300
        timeout_seconds       = 30
        failure_threshold     = 3
        period_seconds        = 30
      }
    }
    
    # Volumes
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
        default_mode = 0644
        items {
          version = "latest"
          path    = "jenkins.yaml"
        }
      }
    }
    
    # Service account
    service_account = google_service_account.jenkins_sa.email
    
    # VPC connector for private networking
    vpc_access {
      connector = google_vpc_access_connector.jenkins_connector.name
      egress    = "PRIVATE_RANGES_ONLY"
    }
    
    # Session affinity for Jenkins
    session_affinity = true
    
    # Execution environment
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
  }
  
  # Traffic configuration
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
  
  labels = var.labels
  
  depends_on = [
    google_vpc_access_connector.jenkins_connector,
    google_secret_manager_secret_version.jenkins_config
  ]
}

# IAM policy for Cloud Run service (private access only)
resource "google_cloud_run_service_iam_policy" "jenkins_private" {
  location = google_cloud_run_v2_service.jenkins.location
  project  = google_cloud_run_v2_service.jenkins.project
  service  = google_cloud_run_v2_service.jenkins.name

  policy_data = data.google_iam_policy.jenkins_private.policy_data
}

data "google_iam_policy" "jenkins_private" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${google_service_account.jenkins_sa.email}",
    ]
  }
}

# Secret for Jenkins configuration as code
resource "google_secret_manager_secret" "jenkins_config" {
  secret_id = "jenkins-config"
  
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
  secret_data = templatefile("${path.module}/config/jenkins.yaml", {
    admin_password = var.jenkins_admin_password
    user_password  = var.jenkins_user_password
    project_id     = var.project_id
    region         = var.region
    zone           = var.zone
    network        = google_compute_network.jenkins_vpc.name
    subnetwork     = google_compute_subnetwork.jenkins_subnet.name
  })
}
