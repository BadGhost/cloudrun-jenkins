terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }
  
  # For production, use GCS backend:
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "jenkins/dev"
  # }
}
