#!/bin/bash

# Script to retrieve Jenkins initial admin password from Cloud Run logs
# Use this when Jenkins shows the "Getting Started" unlock screen

set -e  # Exit on any error

SERVICE_NAME="jenkins-ultra-frugal"
REGION="us-central1"

echo "🔍 Retrieving Jenkins initial admin password..."
echo "📋 Service: $SERVICE_NAME"
echo "🌍 Region: $REGION"
echo ""

# Get the password from logs
echo "⏳ Searching Cloud Run logs for initial admin password..."
PASSWORD=$(gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=200 | \
           grep -A1 "Please use the following password" | \
           tail -1 | \
           sed 's/^[0-9-]* [0-9:]* //' | \
           tr -d ' \t\n\r')

if [ -n "$PASSWORD" ] && [ ${#PASSWORD} -eq 32 ]; then
    echo "✅ Found Jenkins Initial Admin Password!"
    echo ""
    echo "🔑 Password: $PASSWORD"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Copy this password: $PASSWORD"
    echo "2. Paste it in the Jenkins 'Administrator password' field"
    echo "3. Click 'Continue' to proceed with setup"
    echo "4. Complete the setup wizard (you can skip plugin installation)"
    echo "5. After setup, use configured credentials:"
    echo "   - Username: admin"
    echo "   - Password: @Simonza01"
    echo ""
    echo "🌐 Jenkins URL: https://jenkins-34-8-123-99.nip.io/jenkins"
    
    # Copy to clipboard if possible (Windows with Git Bash)
    if command -v clip.exe >/dev/null 2>&1; then
        echo "$PASSWORD" | clip.exe
        echo "📋 Password copied to clipboard!"
    fi
    
else
    echo "❌ Could not find a valid 32-character password."
    echo "🔍 Showing recent password-related log entries:"
    echo ""
    
    gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50 | \
    grep -i -E "password|initial|setup|unlock" | \
    head -10
    
    echo ""
    echo "💡 Troubleshooting:"
    echo "1. Jenkins may still be starting up - wait a few minutes and try again"
    echo "2. Check if Jenkins container restarted recently:"
    echo "   gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=20"
    echo "3. Verify the service is running:"
    echo "   gcloud run services describe $SERVICE_NAME --region=$REGION"
fi

echo ""
echo "🆘 Need help? Check the documentation:"
echo "   docs/JENKINS_INITIAL_SETUP.md"
