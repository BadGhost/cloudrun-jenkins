# Jenkins on GCP - Cost-Effective Serverless Deployment

This repository contains Terraform configuration for deploying Jenkins on Google Cloud Platform with the following features:

## Architecture
- **Jenkins Controller**: Cloud Run (serverless, private)
- **Persistent Storage**: Cloud Storage + Persistent Disk
- **Jenkins Agents**: Preemptible VM instances (90% cost savings)
- **Access**: VPN-only access for security
- **Region**: asia-east1 (Taiwan) for cost optimization
- **Budget**: Designed for ~$2/month usage

## Features
- Jenkins latest version with plugins:
  - AWS Credentials Plugin
  - Docker Pipeline
  - Pipeline Graph View
  - Kubernetes Plugin for dynamic agents
- Private networking with VPN access
- Persistent job history and configurations
- Auto-scaling agents for Docker builds

## Prerequisites
1. Google Cloud SDK installed and configured
2. Terraform installed
3. A GCP project with billing enabled
4. VPN client software

## Deployment Steps
1. Clone this repository
2. Update `terraform.tfvars` with your values
3. Run `terraform init`
4. Run `terraform plan`
5. Run `terraform apply`

## Security Features
- Private Cloud Run service (no public access)
- VPN-only connectivity
- IAM roles with least privilege
- Network security policies
- Built-in Jenkins user database

## Cost Optimization
- Serverless Jenkins controller (pay per use)
- Preemptible VM agents (90% discount)
- Optimized storage configuration
- Auto-shutdown policies

## Maintenance
- Jenkins automatically updates plugins
- Terraform manages infrastructure state
- Backup configurations included
