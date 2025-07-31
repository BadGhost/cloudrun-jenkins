#!/bin/bash

# Ultra-Frugal Spot VM Jenkins Agent Startup Script
# Optimized for maximum cost savings and minimal resource usage

set -e

# Update system with minimal packages only
apt-get update
apt-get install -y \
    default-jre-headless \
    docker.io \
    git \
    curl \
    wget \
    python3-minimal \
    --no-install-recommends

# Clean package cache immediately to save disk space
apt-get clean
rm -rf /var/lib/apt/lists/*

# Configure Docker for minimal resource usage
systemctl enable docker
systemctl start docker
usermod -aG docker debian

# Install minimal Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install minimal gcloud CLI (for storage access)
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update && apt-get install -y google-cloud-cli --no-install-recommends
apt-get clean

# Create jenkins user with minimal setup
useradd -m -s /bin/bash jenkins
usermod -aG docker jenkins

# Ultra-minimal Jenkins agent directory
mkdir -p /opt/jenkins
chown jenkins:jenkins /opt/jenkins

# Configure aggressive cleanup for cost optimization
cat << 'EOF' > /etc/systemd/system/ultra-cleanup.service
[Unit]
Description=Ultra-Frugal Cleanup Service
DefaultDependencies=false
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/true
ExecStop=/bin/bash -c '
  # Aggressive cleanup for cost savings
  docker system prune -af --volumes || true
  apt-get autoremove -y || true
  apt-get autoclean || true
  find /tmp -type f -delete || true
  find /var/tmp -type f -delete || true
  journalctl --vacuum-time=1d || true
'
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ultra-cleanup.service
systemctl start ultra-cleanup.service

# Ultra-aggressive log rotation for cost savings
cat << 'EOF' > /etc/logrotate.d/ultra-frugal
/var/log/*.log {
    daily
    rotate 2
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    size 10M
}
EOF

# Set up automatic shutdown when idle (cost optimization)
cat << 'EOF' > /usr/local/bin/idle-shutdown.sh
#!/bin/bash
# Shutdown if no Docker containers running and low CPU for 10 minutes

IDLE_COUNT=0
while true; do
  CONTAINER_COUNT=$(docker ps -q | wc -l)
  CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
  
  if [ "$CONTAINER_COUNT" -eq 0 ] && [ "$${CPU_USAGE%.*}" -lt 5 ]; then
    IDLE_COUNT=$((IDLE_COUNT + 1))
    if [ "$IDLE_COUNT" -ge 10 ]; then  # 10 minutes of idle
      echo "System idle for 10 minutes, shutting down for cost savings"
      sudo shutdown -h now
    fi
  else
    IDLE_COUNT=0
  fi
  
  sleep 60  # Check every minute
done
EOF

chmod +x /usr/local/bin/idle-shutdown.sh

# Start idle monitoring as background service
cat << 'EOF' > /etc/systemd/system/idle-shutdown.service
[Unit]
Description=Idle Shutdown Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/idle-shutdown.sh
Restart=always
User=jenkins

[Install]
WantedBy=multi-user.target
EOF

systemctl enable idle-shutdown.service
systemctl start idle-shutdown.service

# Signal that the ultra-frugal agent is ready
touch /tmp/jenkins-spot-agent-ready

echo "Ultra-frugal Jenkins Spot agent setup completed successfully!"
echo "Cost optimizations: minimal packages, aggressive cleanup, idle shutdown"
