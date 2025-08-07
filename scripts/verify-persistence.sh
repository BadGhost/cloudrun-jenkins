#!/bin/bash

# Script to truly verify Jenkins persistence by creating a job,
# forcing a scale-to-zero event, and then checking if the job still exists.

set -e

PROJECT_ID="${1:-}"
if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <PROJECT_ID>"
    echo "Example: $0 my-ultra-frugal-jenkins"
    exit 1
fi

echo "🚀 Starting end-to-end persistence verification for project: $PROJECT_ID"
echo "======================================================================"

# --- Jenkins Credentials and Configuration ---
JENKINS_USER="admin"
JENKINS_PASS="@Simonza01" # Default password from JCasC
SERVICE_NAME="jenkins-ultra-frugal"
REGION="us-central1"

# 1. Get Jenkins Service URL
echo "1. Fetching Jenkins service URL..."
JENKINS_URL=$(gcloud run services describe $SERVICE_NAME \
    --platform=managed \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(status.url)")

if [ -z "$JENKINS_URL" ]; then
    echo "❌ Could not retrieve Jenkins URL. Is the service deployed?"
    exit 1
fi
echo "✅ Jenkins URL: $JENKINS_URL"

# 2. Create a unique job to test persistence
JOB_NAME="persistence-test-$(date +%s)"
echo "2. Creating a unique test job in Jenkins: $JOB_NAME"

# Simple shell command job XML
JOB_XML="<project><description>Test job to verify persistence.</description><keepDependencies>false</keepDependencies><properties/><scm class=\"hudson.scm.NullSCM\"/><canRoam>true</canRoam><disabled>false</disabled><blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding><blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding><triggers/><concurrentBuild>false</concurrentBuild><builders><hudson.tasks.Shell><command>echo 'Persistence test successful!'</command></hudson.tasks.Shell></builders><publishers/><buildWrappers/></project>"

CREATE_RESPONSE=$(curl -s -X POST "$JENKINS_URL/jenkins/createItem?name=$JOB_NAME" \
    --user "$JENKINS_USER:$JENKINS_PASS" \
    -H "Content-Type: application/xml" \
    --data-binary "$JOB_XML" \
    --write-out "%{http_code}" \
    --output /dev/null)

if [ "$CREATE_RESPONSE" -ne 200 ]; then
    echo "❌ Failed to create Jenkins job. HTTP status: $CREATE_RESPONSE"
    echo "   Please check credentials and ensure Jenkins is running."
    exit 1
fi
echo "✅ Jenkins job '$JOB_NAME' created successfully."

# 3. Force a scale-to-zero and restart
echo "3. Forcing a restart by scaling Cloud Run service to zero and back..."

# Scale down (allow failure in case it's already at 0)
gcloud run services update $SERVICE_NAME \
    --platform=managed \
    --region=$REGION \
    --project=$PROJECT_ID \
    --max-instances=0 \
    --quiet || true
echo "   Scaled down to max-instances=0. Waiting 60 seconds for instance to terminate..."
sleep 60

# Scale back up
gcloud run services update $SERVICE_NAME \
    --platform=managed \
    --region=$REGION \
    --project=$PROJECT_ID \
    --max-instances=1 \
    --quiet
echo "   Scaled up to max-instances=1. Waiting 90 seconds for Jenkins to restart..."
sleep 90

# 4. Verify the job still exists
echo "4. Verifying if job '$JOB_NAME' still exists after restart..."
VERIFY_RESPONSE=$(curl -s -I -L "$JENKINS_URL/jenkins/job/$JOB_NAME/" \
    --user "$JENKINS_USER:$JENKINS_PASS" \
    | grep -i "HTTP/2")


if [[ "$VERIFY_RESPONSE" == *"200"* ]]; then
    echo "🎉 SUCCESS: Jenkins job '$JOB_NAME' persists after restart!"
    echo "✅ Persistence is working correctly."
    # Clean up the test job
    curl -s -X POST "$JENKINS_URL/jenkins/job/$JOB_NAME/doDelete" --user "$JENKINS_USER:$JENKINS_PASS" > /dev/null
    echo "   Cleaned up test job."
    exit 0
else
    echo "❌ FAILURE: Jenkins job '$JOB_NAME' does NOT exist after restart."
    echo "   HTTP status from check: $(echo "$VERIFY_RESPONSE" | awk '{print $2}')"
    echo "   Persistence is NOT working correctly."
    exit 1
fi
