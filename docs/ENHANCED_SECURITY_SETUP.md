# Enhanced Security Setup for Ultra-Frugal Jenkins

This guide provides two security options for your Jenkins deployment: **IAP Authentication** (preferred) and **IP-based Security** (fallback).

## 🔐 Option 1: IAP Authentication (Recommended)

### What is IAP?
Identity-Aware Proxy provides Google-grade authentication without VPN infrastructure:
- **Zero-trust security**: Every request is authenticated
- **Google SSO**: Uses your existing Google accounts
- **No additional costs**: Free for most use cases
- **Universal access**: Works from any browser, anywhere

### How to Enable IAP

1. **Run the IAP setup script**:
   ```bash
   ./enable-iap.sh
   ```

2. **Follow the prompts** to deploy IAP configuration

3. **Test access** at your Jenkins URL

### IAP Authentication Flow
```
User Browser → Google Sign-In → IAP Verification → Jenkins
```

### If IAP Fails (Personal Project Limitations)
Some personal Google Cloud projects don't support IAP brands. If you see errors like:
- "IAP brand creation failed"
- "OAuth client creation failed"

**→ Use Option 2: IP-based Security instead**

## 🏠 Option 2: IP-based Security (Fallback)

### When to Use
- IAP setup fails due to project limitations
- You access Jenkins from fixed locations only
- You prefer traditional IP allowlisting

### How to Setup IP Security

1. **Run the IP security script**:
   ```bash
   ./setup-ip-security.sh
   ```

2. **The script will**:
   - Detect your current public IP
   - Ask for additional IPs (office, home, etc.)
   - Create firewall rules to block unauthorized access

3. **Apply the configuration** when prompted

### IP Security Features
- ✅ **Automatic IP detection**: Finds your current public IP
- ✅ **Multiple IPs**: Add home, office, mobile hotspot IPs
- ✅ **Firewall protection**: GCP-level blocking of unauthorized IPs
- ⚠️ **Manual updates needed**: When your IP changes

## 🔄 Security Comparison

| Feature | IAP Authentication | IP-based Security |
|---------|-------------------|-------------------|
| **Cost** | Free | Free |
| **Setup Complexity** | Medium | Low |
| **Mobile Access** | ✅ Anywhere | ❌ Fixed IPs only |
| **Google SSO** | ✅ Built-in | ❌ Jenkins auth only |
| **IP Changes** | ✅ No issues | ❌ Manual updates |
| **Security Level** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## 🛠️ Advanced Configuration

### Custom IAP Settings
Edit `cloudrun.tf` to customize IAP:

```terraform
resource "google_iap_brand" "jenkins_brand" {
  support_email     = "your-admin@email.com"
  application_title = "My Jenkins CI/CD"
  # ... other settings
}
```

### Custom IP Allowlist
Edit `ip-allowlist.tf` to modify allowed IPs:

```terraform
resource "google_compute_firewall" "jenkins_ip_allowlist" {
  source_ranges = [
    "203.0.113.1/32",    # Office IP
    "198.51.100.0/24",   # Office network
    "192.0.2.100/32"     # Home IP
  ]
  # ... other settings
}
```

## 🔍 Troubleshooting

### IAP Issues

**Problem**: "Access Denied" after Google Sign-In
**Solution**: Verify your email is in `authorized_users` list:
```bash
grep -A 5 "authorized_users" environments/dev/terraform.tfvars
```

**Problem**: IAP setup fails completely
**Solution**: Use IP-based security instead:
```bash
./setup-ip-security.sh
```

### IP Security Issues

**Problem**: Can't access Jenkins after IP change
**Solution**: Update your IP allowlist:
```bash
# Get your new IP
curl https://ipinfo.io/ip

# Edit ip-allowlist.tf with new IP
# Apply changes
cd environments/dev
terraform apply
```

**Problem**: Need to add new location
**Solution**: Re-run the setup script:
```bash
./setup-ip-security.sh
```

## 🔒 Security Best Practices

### For Both Options
1. **Use strong Jenkins passwords** (already configured in terraform.tfvars)
2. **Enable HTTPS only** (already configured)
3. **Monitor access logs** regularly
4. **Keep Jenkins updated**

### IAP-Specific
1. **Review authorized users** quarterly
2. **Monitor IAP audit logs** in Cloud Console
3. **Use organizational accounts** when possible

### IP-based Specific
1. **Update IPs when they change**
2. **Use smallest possible IP ranges**
3. **Document all allowed IPs**

## 📊 Monitoring Access

### Check Current Security Status
```bash
# For IAP
gcloud iap oauth-brands list --project=YOUR_PROJECT_ID

# For IP security
gcloud compute firewall-rules list --filter="name:jenkins"

# Jenkins access logs
gcloud run services logs read jenkins-ultra-frugal --region=us-central1
```

### Access Analytics
Monitor authentication in:
- **Cloud Console** → Security → Identity-Aware Proxy
- **Cloud Console** → VPC → Firewall
- **Jenkins** → Manage → System Log

## 🚀 Next Steps

After securing your Jenkins:

1. **Complete Jenkins initial setup** if prompted
2. **Install required plugins** for your CI/CD needs
3. **Configure build agents** (spot VMs already configured)
4. **Set up your first pipeline**

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review GCP Console for error messages
3. Check Jenkins system logs
4. Verify network connectivity

Remember: Security is layered - Jenkins authentication works **in addition to** IAP/IP protection.
