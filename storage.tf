# Cloud Storage bucket for Jenkins data
resource "google_storage_bucket" "jenkins_storage" {
  name          = "${var.project_id}-jenkins-storage"
  location      = var.region
  force_destroy = false
  
  # Cost optimization settings
  storage_class = "STANDARD"
  
  # Lifecycle management to control costs
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
  
  # Security settings
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  labels = var.labels
}

# Persistent disk for Jenkins home directory
resource "google_compute_disk" "jenkins_home" {
  name  = "jenkins-home-disk"
  type  = "pd-standard"  # Standard persistent disk for cost optimization
  zone  = var.zone
  size  = var.storage_size
  
  labels = var.labels
}

# Service account for Jenkins
resource "google_service_account" "jenkins_sa" {
  account_id   = "jenkins-service-account"
  display_name = "Jenkins Service Account"
  description  = "Service account for Jenkins controller and agents"
}

# IAM bindings for Jenkins service account
resource "google_project_iam_member" "jenkins_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

resource "google_project_iam_member" "jenkins_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

resource "google_project_iam_member" "jenkins_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

# Secret Manager for storing sensitive data
resource "google_secret_manager_secret" "jenkins_admin_password" {
  secret_id = "jenkins-admin-password"
  
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "jenkins_admin_password" {
  secret      = google_secret_manager_secret.jenkins_admin_password.id
  secret_data = var.jenkins_admin_password
}

resource "google_secret_manager_secret" "jenkins_user_password" {
  secret_id = "jenkins-user-password"
  
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "jenkins_user_password" {
  secret      = google_secret_manager_secret.jenkins_user_password.id
  secret_data = var.jenkins_user_password
}

# IAM for Secret Manager access
resource "google_project_iam_member" "jenkins_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}
