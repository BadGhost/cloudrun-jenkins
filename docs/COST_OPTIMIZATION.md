# Cost Optimization Guide for Jenkins on GCP

This guide explains how the deployment is optimized for your $2/month budget and provides tips for further cost reduction.

## Current Cost Optimization Features

### 1. Serverless Jenkins Controller
- **Cloud Run**: Pay only when Jenkins is actively being used
- **Scale to Zero**: Automatically shuts down when idle
- **Resource Limits**: CPU and memory limits prevent runaway costs
- **Estimated Cost**: ~$0.50-1.00/month with light usage

### 2. Preemptible VM Agents
- **90% Cost Savings**: Preemptible instances cost 90% less than regular VMs
- **Auto-scaling**: Scales from 0 to 3 agents based on demand
- **Efficient Scheduling**: Agents terminate when jobs complete
- **Estimated Cost**: ~$0.30-0.80/month with moderate usage

### 3. Storage Optimization
- **Lifecycle Management**: Data automatically moves to cheaper storage after 90 days
- **Standard Storage**: Cost-effective for frequently accessed data
- **Deletion Policy**: Old data deleted after 1 year
- **Estimated Cost**: ~$0.20-0.40/month for 10GB

### 4. Network Optimization
- **Regional Deployment**: asia-east1 offers lower costs than premium regions
- **Private Networking**: No NAT gateway costs (VPN-only access)
- **Minimal VPC Connector**: Small connector instances
- **Estimated Cost**: ~$0.30-0.50/month

## Total Estimated Monthly Costs

| Component | Cost Range | Optimization |
|-----------|------------|--------------|
| Cloud Run Controller | $0.50 - $1.00 | Scales to zero when idle |
| VM Agents (preemptible) | $0.30 - $0.80 | 90% discount, auto-shutdown |
| Storage (10GB + lifecycle) | $0.20 - $0.40 | Automatic archival/deletion |
| Networking (VPC/VPN) | $0.30 - $0.50 | Regional, minimal config |
| **Total** | **$1.30 - $2.70** | **Within budget range** |

## Additional Cost Reduction Tips

### 1. Usage Patterns
```bash
# Monitor your usage patterns
gcloud logging read "resource.type=cloud_run_revision" --limit=50 --format="table(timestamp,resource.labels.service_name)"

# Check VM agent usage
gcloud compute instances list --filter="name:jenkins-agent*" --format="table(name,status,creationTimestamp)"
```

### 2. Optimize Jenkins Jobs
- **Parallel Execution**: Use Jenkins Pipeline parallel execution
- **Efficient Agents**: Right-size agents for specific job types
- **Job Cleanup**: Clean workspace after builds
- **Plugin Optimization**: Only install necessary plugins

### 3. Storage Management
```groovy
// Jenkins Pipeline for cleanup
pipeline {
    agent any
    triggers {
        cron('0 2 * * 0') // Weekly cleanup
    }
    stages {
        stage('Cleanup') {
            steps {
                script {
                    // Clean old builds
                    currentBuild.getParent().builds.findAll { 
                        it.number < currentBuild.number - 10 
                    }.each { 
                        it.delete() 
                    }
                }
            }
        }
    }
}
```

### 4. Resource Monitoring
Set up budget alerts:
```bash
# Create budget alert
gcloud billing budgets create \
    --billing-account=YOUR_BILLING_ACCOUNT \
    --display-name="Jenkins Monthly Budget" \
    --budget-amount=2USD \
    --threshold-rule=percent=0.8 \
    --threshold-rule=percent=1.0
```

### 5. Scheduled Shutdowns
For development environments, consider scheduled shutdowns:
```yaml
# Cloud Scheduler job to stop Jenkins during off-hours
name: jenkins-night-shutdown
schedule: "0 23 * * 1-5"  # 11 PM on weekdays
time_zone: "Asia/Kuala_Lumpur"
target:
  http_target:
    uri: "https://cloudrun.googleapis.com/v2/projects/PROJECT_ID/locations/REGION/services/jenkins-controller:stop"
```

## Cost Monitoring Dashboard

### 1. GCP Console Monitoring
- Navigate to **Billing** > **Budgets & alerts**
- Set up alerts at 50%, 80%, and 100% of budget
- Monitor **Cloud Run**, **Compute Engine**, and **Storage** usage

### 2. Custom Monitoring Script
```bash
#!/bin/bash
# monthly_cost_check.sh

PROJECT_ID="your-project-id"
BUDGET_LIMIT=2.00

# Get current month costs
CURRENT_COST=$(gcloud billing projects describe $PROJECT_ID \
    --format="value(billingAccountName)" | \
    xargs gcloud billing accounts describe \
    --format="value(displayName)")

echo "Current month Jenkins costs: $CURRENT_COST"
echo "Budget limit: $BUDGET_LIMIT"

# Add alert logic here
```

### 3. Jenkins Plugin for Cost Monitoring
Install the **Build Cost Plugin** to track:
- Agent usage costs
- Build duration costs
- Resource consumption per job

## Emergency Cost Control

If costs exceed budget:

### 1. Immediate Actions
```bash
# Stop all agents
gcloud compute instances stop --zone=asia-east1-a $(gcloud compute instances list --format="value(name)" --filter="name:jenkins-agent*")

# Scale Cloud Run to zero
gcloud run services update jenkins-controller --region=asia-east1 --min-instances=0 --max-instances=0
```

### 2. Temporary Measures
- Disable automatic agent provisioning
- Reduce storage retention periods
- Pause non-critical scheduled jobs

### 3. Configuration Adjustments
```hcl
# Reduce agent limits in variables.tf
variable "max_agents" {
  default = 1  # Reduced from 3
}

# Reduce storage size
variable "storage_size" {
  default = 5  # Reduced from 10GB
}
```

## Long-term Optimization Strategies

### 1. Usage Analytics
- Track job patterns and optimize schedules
- Identify resource-heavy jobs
- Optimize Docker images for faster builds

### 2. Alternative Architectures
For extremely low usage:
- Consider GitHub Actions (2000 free minutes/month)
- Use Cloud Build with free tier (120 build-minutes/day)
- Implement webhook-based builds only

### 3. Hybrid Approach
- Keep Jenkins for complex workflows
- Use Cloud Build for simple CI/CD
- Implement smart routing based on job complexity

## Best Practices Summary

1. **Monitor Daily**: Check costs daily during first month
2. **Optimize Continuously**: Regular review and optimization
3. **Alert Early**: Set alerts at 50% budget usage
4. **Plan Capacity**: Understand your actual usage patterns
5. **Emergency Procedures**: Have cost control procedures ready

Remember: The goal is reliable CI/CD within budget, not maximum performance. This configuration prioritizes cost-effectiveness while maintaining functionality.
