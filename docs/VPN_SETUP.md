# Jenkins Deployment - VPN Configuration Guide

This guide helps you configure VPN access to your private Jenkins deployment.

## VPN Gateway Information

After running `terraform apply`, you'll get the VPN gateway IP address from the output. Use this information to configure your VPN client.

## Client Configuration

### For Windows (Built-in VPN Client)

1. Open **Settings** > **Network & Internet** > **VPN**
2. Click **Add a VPN connection**
3. Configure:
   - **VPN provider**: Windows (built-in)
   - **Connection name**: Jenkins GCP
   - **Server name or address**: [VPN Gateway IP from terraform output]
   - **VPN type**: IKEv2
   - **Type of sign-in info**: Pre-shared key
   - **Pre-shared key**: [vpn_shared_secret from your terraform.tfvars]

### For macOS (Built-in VPN Client)

1. Open **System Preferences** > **Network**
2. Click **+** to add a new connection
3. Configure:
   - **Interface**: VPN
   - **VPN Type**: IKEv2
   - **Service Name**: Jenkins GCP
4. In **Server Address**: [VPN Gateway IP]
5. In **Remote ID**: [VPN Gateway IP]
6. Click **Authentication Settings**:
   - **Authentication**: Shared Secret
   - **Shared Secret**: [vpn_shared_secret from terraform.tfvars]

### For Linux (strongSwan)

1. Install strongSwan:
   ```bash
   sudo apt-get install strongswan
   ```

2. Configure `/etc/ipsec.conf`:
   ```
   conn jenkins-gcp
       type=tunnel
       keyexchange=ikev2
       left=%defaultroute
       leftauth=psk
       right=[VPN Gateway IP]
       rightauth=psk
       rightsubnet=10.0.0.0/24
       ike=aes256-sha1-modp1024!
       esp=aes256-sha1!
       auto=add
   ```

3. Configure `/etc/ipsec.secrets`:
   ```
   %any [VPN Gateway IP] : PSK "[vpn_shared_secret]"
   ```

4. Start the connection:
   ```bash
   sudo ipsec up jenkins-gcp
   ```

## Mobile Devices

### iOS
1. Go to **Settings** > **General** > **VPN & Device Management** > **VPN**
2. Add VPN Configuration > **IKEv2**
3. Configure:
   - **Description**: Jenkins GCP
   - **Server**: [VPN Gateway IP]
   - **Remote ID**: [VPN Gateway IP]
   - **Local ID**: Leave blank
   - **User Authentication**: None
   - **Use Certificate**: OFF
   - **Secret**: [vpn_shared_secret]

### Android
1. Go to **Settings** > **Network & Internet** > **VPN**
2. Add VPN Profile
3. Configure:
   - **Name**: Jenkins GCP
   - **Type**: IKEv2/IPSec PSK
   - **Server address**: [VPN Gateway IP]
   - **IPSec pre-shared key**: [vpn_shared_secret]

## Troubleshooting

### Connection Issues
1. Verify your home public IP is correctly configured in `network.tf`
2. Check that the VPN shared secret matches exactly
3. Ensure your local firewall allows VPN traffic

### DNS Resolution
If you can connect via VPN but can't access Jenkins:
1. Check that you're using the internal Jenkins URL
2. Verify Cloud Run service is running
3. Check VPC connector configuration

### Performance Issues
1. Monitor VPN connection quality
2. Check Cloud Run service logs
3. Verify agent instances are starting correctly

## Security Best Practices

1. **Change Default Passwords**: Immediately change the default admin and user passwords after first login
2. **Enable 2FA**: Consider enabling two-factor authentication plugins
3. **Regular Updates**: Keep Jenkins and plugins updated
4. **Access Logging**: Monitor Jenkins access logs regularly
5. **VPN Rotation**: Rotate VPN shared secrets periodically

## Cost Monitoring

1. **Set Budget Alerts**: Configure billing alerts in GCP Console
2. **Monitor Usage**: Check Cloud Run and Compute Engine usage regularly
3. **Optimize Resources**: Adjust instance sizes based on actual usage
4. **Review Logs**: Clean up old logs and artifacts periodically

## Support

For issues:
1. Check Terraform state: `terraform show`
2. View Cloud Run logs in GCP Console
3. Monitor VPN gateway status
4. Review Jenkins system logs
