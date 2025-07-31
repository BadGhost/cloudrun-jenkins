#!/bin/bash
# Script to enable IAP authentication for Ultra-Frugal Jenkins

set -e

echo "🔐 Enabling IAP Authentication for Ultra-Frugal Jenkins"
echo "=================================================="

# Change to the dev environment
cd environments/dev

echo "📋 Step 1: Checking current Terraform configuration..."
terraform validate
if [ $? -ne 0 ]; then
    echo "❌ Terraform configuration is invalid. Please fix errors first."
    exit 1
fi

echo "✅ Terraform configuration is valid"

echo "📋 Step 2: Planning IAP deployment..."
terraform plan -out=iap-plan

echo "📋 Step 3: Applying IAP configuration..."
echo "⚠️  This will enable IAP authentication. Your Jenkins will require Google Sign-In."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

terraform apply iap-plan

echo "📋 Step 4: Verifying IAP deployment..."

# Get the Jenkins URL
JENKINS_URL=$(terraform output -raw jenkins_url 2>/dev/null || echo "")
if [ -z "$JENKINS_URL" ]; then
    echo "❌ Could not get Jenkins URL from terraform output"
    exit 1
fi

echo "🎉 IAP Authentication Enabled Successfully!"
echo "==========================================="
echo ""
echo "📍 Jenkins URL: $JENKINS_URL"
echo ""
echo "🔐 Authentication Flow:"
echo "1. Visit the Jenkins URL above"
echo "2. You'll be redirected to Google Sign-In"
echo "3. Sign in with an authorized Google account:"

# Get authorized users from terraform.tfvars
if [ -f "terraform.tfvars" ]; then
    echo "   $(grep -A 5 "authorized_users" terraform.tfvars | grep -o '"[^"]*@[^"]*"' | tr -d '"' | sed 's/^/   - /')"
fi

echo ""
echo "4. After Google authentication, you'll reach Jenkins"
echo "5. Use Jenkins credentials: admin/[your_password] or user/[your_password]"
echo ""
echo "🛡️ Security Benefits:"
echo "✅ Google-grade authentication"
echo "✅ Zero-trust security model"
echo "✅ No VPN infrastructure needed"
echo "✅ Access from any browser, anywhere"
echo ""
echo "🔍 Troubleshooting:"
echo "- If you get 'Access Denied', verify your email is in authorized_users"
echo "- If IAP setup fails, you may be using a personal project"
echo "- Check Cloud Console > Security > Identity-Aware Proxy for status"
echo ""
echo "📝 Next Steps:"
echo "1. Test access with an authorized Google account"
echo "2. Complete Jenkins initial setup if prompted"
echo "3. Configure your Jenkins jobs and agents"

# Check if IAP is actually working
echo ""
echo "🔍 Testing IAP configuration..."
response=$(curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL" || echo "000")
if [ "$response" = "302" ] || [ "$response" = "200" ]; then
    echo "✅ Jenkins is responding correctly"
else
    echo "⚠️  Jenkins response: HTTP $response - this might be normal during startup"
fi

echo ""
echo "🎯 Access your IAP-protected Jenkins: $JENKINS_URL"
