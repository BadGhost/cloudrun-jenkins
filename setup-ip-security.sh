#!/bin/bash
# Script to implement IP-based security as IAP alternative

set -e

echo "🔒 Setting up IP-based Security for Ultra-Frugal Jenkins"
echo "======================================================"

# Get current public IP
echo "📡 Detecting your current public IP address..."
CURRENT_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null || echo "")

if [ -z "$CURRENT_IP" ]; then
    echo "❌ Could not detect your public IP address"
    echo "Please manually find your IP and update the script"
    exit 1
fi

echo "✅ Your current public IP: $CURRENT_IP"

# Ask for additional IPs
echo ""
echo "📝 Do you want to add additional IP addresses?"
echo "   (e.g., office IP, home IP, etc.)"
read -p "Enter additional IPs (comma-separated) or press Enter to skip: " ADDITIONAL_IPS

# Prepare IP list
IP_LIST="$CURRENT_IP/32"
if [ ! -z "$ADDITIONAL_IPS" ]; then
    # Clean up the input and add /32 to each IP
    CLEANED_IPS=$(echo "$ADDITIONAL_IPS" | tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/$/\/32/' | tr '\n' ',' | sed 's/,$//')
    IP_LIST="$IP_LIST,$CLEANED_IPS"
fi

echo ""
echo "🔐 Will restrict access to these IPs:"
echo "$IP_LIST" | tr ',' '\n' | sed 's/^/   - /'

# Create IP allowlist configuration
cat > ip-allowlist.tf << EOF
# IP-based access control for Jenkins (IAP alternative)
resource "google_compute_firewall" "jenkins_ip_allowlist" {
  name        = "jenkins-ip-allowlist"
  network     = google_compute_network.jenkins_vpc.name
  description = "Allow HTTPS access only from specific IP addresses"
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  source_ranges = [$(echo "$IP_LIST" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')]
  target_tags   = ["jenkins", "iap-access"]
  priority      = 100
}

# Block all other HTTPS access
resource "google_compute_firewall" "jenkins_block_others" {
  name        = "jenkins-block-others"
  network     = google_compute_network.jenkins_vpc.name
  description = "Block HTTPS access from all other IPs"
  
  deny {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins", "iap-access"]
  priority      = 200
}
EOF

echo ""
echo "📝 Created IP allowlist configuration in ip-allowlist.tf"

# Ask if user wants to apply
echo ""
read -p "Apply IP-based security now? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Configuration saved but not applied"
    echo "📝 To apply later, run: terraform apply"
    exit 0
fi

# Apply the configuration
cd environments/dev

echo "📋 Applying IP-based security..."
terraform plan -target=google_compute_firewall.jenkins_ip_allowlist -target=google_compute_firewall.jenkins_block_others

echo ""
read -p "Proceed with applying firewall rules? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

terraform apply -target=google_compute_firewall.jenkins_ip_allowlist -target=google_compute_firewall.jenkins_block_others -auto-approve

echo ""
echo "🎉 IP-based Security Applied Successfully!"
echo "========================================"
echo ""
echo "🔐 Security Configuration:"
echo "✅ HTTPS access allowed only from:"
echo "$IP_LIST" | tr ',' '\n' | sed 's/^/   - /'
echo "❌ All other IPs are blocked"
echo ""
echo "🚨 Important Notes:"
echo "- Your IP changes when you move locations"
echo "- Update the allowlist when your IP changes"
echo "- Jenkins still requires username/password authentication"
echo ""
echo "📝 To update IP allowlist later:"
echo "1. Edit ip-allowlist.tf"
echo "2. Run: terraform apply"
echo ""

# Get Jenkins URL
JENKINS_URL=$(terraform output -raw jenkins_url 2>/dev/null || echo "")
if [ ! -z "$JENKINS_URL" ]; then
    echo "🎯 Access your IP-protected Jenkins: $JENKINS_URL"
fi
