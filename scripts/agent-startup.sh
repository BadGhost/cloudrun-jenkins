#!/bin/bash

# Jenkins Agent Startup Script
# This script configures a VM to act as a Jenkins agent

set -e

# Update system
apt-get update
apt-get install -y \
    default-jre \
    docker.io \
    git \
    curl \
    wget \
    unzip \
    python3 \
    python3-pip

# Configure Docker
systemctl enable docker
systemctl start docker
usermod -aG docker debian

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update && apt-get install -y terraform

# Install gcloud CLI
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt-get update && apt-get install -y google-cloud-cli

# Create jenkins user
useradd -m -s /bin/bash jenkins
usermod -aG docker jenkins
usermod -aG sudo jenkins

# Create Jenkins agent directory
mkdir -p /opt/jenkins
chown jenkins:jenkins /opt/jenkins

# Install Jenkins agent jar (will be downloaded by Jenkins when needed)
mkdir -p /opt/jenkins/bin
chown jenkins:jenkins /opt/jenkins/bin

# Set up automatic cleanup on shutdown (cost optimization)
cat << 'EOF' > /etc/systemd/system/jenkins-cleanup.service
[Unit]
Description=Jenkins Agent Cleanup
DefaultDependencies=false
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/true
ExecStop=/bin/bash -c 'docker system prune -af || true'
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable jenkins-cleanup.service
systemctl start jenkins-cleanup.service

# Configure log rotation to save disk space
cat << 'EOF' > /etc/logrotate.d/jenkins-agent
/var/log/jenkins-agent.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 jenkins jenkins
}
EOF

# Signal that the instance is ready
touch /tmp/jenkins-agent-ready

echo "Jenkins agent setup completed successfully"
