terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket-prod"
    prefix = "jenkins/prod"
  }
}
