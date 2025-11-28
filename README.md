# Azure IIS Web Servers with Azure SQL Database and Load Balancer - Terraform

This Terraform project provisions a highly available web infrastructure on Azure with:
- Windows Virtual Machine Scale Set running IIS (Internet Information Services)
- Azure SQL Database (cloud-managed SQL)
- Azure Load Balancer in front of the VMs for web traffic
- Network security group with appropriate rules
- Azure Monitor Autoscale rules for elastic capacity

## Architecture

```
Internet
   |
   v
[Load Balancer] (Public IP)
   |
   v
[VM Scale Set - IIS]  <---->  [Azure SQL Database]
```

## Prerequisites

1. **Azure CLI** installed and configured
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Terraform** installed (version >= 1.0)
   - Download from: https://www.terraform.io/downloads

3. **Azure Service Principal** (optional, for CI/CD)
   - Or use `az login` for local development

## Quick Start

1. **Clone or navigate to this directory**

2. **Copy the example variables file**
   ```bash
   copy terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`** with your values:
   - Set `admin_username` and `admin_password` for VMs
   - Set `sql_admin_username` and `sql_admin_password` for Azure SQL Database
   - Adjust `location`, `vm_size`, and autoscale parameters as needed
   - Configure SQL Database SKU and settings

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

5. **Review the execution plan**
   ```bash
   terraform plan
   ```

6. **Apply the configuration**
   ```bash
   terraform apply
   ```

7. **Get connection information**
   ```bash
   terraform output
   ```

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Name of the resource group | `rg-iis-sql-lb` |
| `location` | Azure region | `East US` |
| `prefix` | Prefix for resource names | `iis` |
| `vnet_address_space` | VNet address space | `10.0.0.0/16` |
| `subnet_address_prefix` | Subnet address prefix | `10.0.1.0/24` |
| `vm_count` | Initial number of VMs (deprecated, prefer autoscale defaults) | `2` |
| `vm_size` | VM size | `Standard_DS2_v2` |
| `vmss_enable_public_ip` | Enable public IP addresses for VM Scale Set instances | `false` |
| `vmss_public_ip_prefix_length` | Public IP prefix length (e.g., 30 for /30 = 4 IPs) | `30` |
| `autoscale_enabled` | Toggle Azure Monitor autoscale | `true` |
| `autoscale_min_instances` | Minimum VMSS instances | `2` |
| `autoscale_max_instances` | Maximum VMSS instances | `10` |
| `autoscale_default_instances` | Starting VMSS capacity | `2` |
| `autoscale_scale_out_cpu_threshold` | CPU % that triggers scale-out | `75` |
| `autoscale_scale_in_cpu_threshold` | CPU % that triggers scale-in | `25` |
| `autoscale_scale_out_step` | Instances added per scale-out event | `1` |
| `autoscale_scale_in_step` | Instances removed per scale-in event | `1` |
| `autoscale_scale_out_cooldown` | Cooldown after scale-out (ISO 8601) | `PT5M` |
| `autoscale_scale_in_cooldown` | Cooldown after scale-in (ISO 8601) | `PT5M` |
| `autoscale_metric_time_grain` | Metric granularity (ISO 8601) | `PT1M` |
| `autoscale_metric_time_window` | Metric window (ISO 8601) | `PT5M` |
| `autoscale_notification_emails` | Emails notified on scale actions | `[]` |
| `windows_server_sku` | Windows Server SKU | `2022-Datacenter` |
| `admin_username` | VM admin username | *required* |
| `admin_password` | VM admin password | *required* |
| `sql_admin_username` | Azure SQL admin username | *required* |
| `sql_admin_password` | Azure SQL admin password | *required* |
| `sql_database_name` | Azure SQL Database name | `appdb` |
| `sql_database_sku` | Azure SQL Database SKU | `S0` |
| `sql_database_max_size_gb` | Max database size in GB | `2` |
| `sql_database_zone_redundant` | Enable zone redundancy | `false` |

### Azure SQL Database SKUs

Common SKU options:
- **S0, S1, S2, S3**: Standard tier (DTU-based)
- **P1, P2, P4, P6, P11, P15**: Premium tier (DTU-based)
- **GP_Gen5_2, GP_Gen5_4, etc.**: General Purpose (vCore-based)
- **BC_Gen5_2, BC_Gen5_4, etc.**: Business Critical (vCore-based)

See [Azure SQL Database pricing](https://azure.microsoft.com/pricing/details/sql-database/) for details.

## Accessing Your Web Application

After deployment, access your web application via the Load Balancer:

```
http://<load_balancer_public_ip>
```

The Load Balancer will distribute traffic across all healthy IIS servers. A default welcome page is automatically created on each VM.

## Connecting to Azure SQL Database

After deployment, you can connect to Azure SQL Database using the connection string from outputs:

```bash
terraform output sql_connection_string_template
```

Or use the SQL Server FQDN:
```
Server: <sql_server_fqdn>
Database: <sql_database_name>
Username: <sql_admin_username>
Password: <sql_admin_password>
```

**Note**: The SQL Database firewall is configured to:
- Allow Azure services (0.0.0.0 - 0.0.0.0)
- Allow access from the VNet subnet

For production, restrict firewall rules to specific IP addresses.

## Deploying Your IIS Application

1. **Connect to a VM** via RDP (see below)
2. **Copy your application files** to `C:\inetpub\wwwroot\`
3. **Configure your application** to connect to Azure SQL Database using the connection string
4. **Test** by accessing the Load Balancer public IP

## Connecting to VMs via RDP

The VMs are in a private subnet by default. To connect via RDP:

1. **Option 1**: Enable public IPs for VM Scale Set instances (easiest for development)
   - Set `vmss_enable_public_ip = true` in `terraform.tfvars`
   - Set `vmss_public_ip_prefix_length` to allocate enough IPs (e.g., 30 for 4 IPs, 28 for 16 IPs)
   - Each VM instance will get its own public IP address
   - Connect directly via RDP using the instance's public IP
   - **Note**: Ensure NSG allows RDP (port 3389) from your IP address

2. **Option 2**: Use Azure Bastion (recommended for production)
   - Create an Azure Bastion resource
   - Connect through Azure Portal

3. **Option 3**: Create a VPN connection
   - Set up Azure VPN Gateway
   - Connect from your local machine

4. **Option 4**: Use Load Balancer NAT rules (for temporary access)
   - Configure NAT rules on the load balancer for RDP
   - Use for troubleshooting only

## Network Security

The Network Security Group allows:
- **Port 3389**: RDP (from any source - restrict in production!)
- **Port 80**: HTTP (from any source)
- **Port 443**: HTTPS (from any source)
- **Health Probes**: From Azure Load Balancer

**Security Recommendations**:
- Restrict RDP source IPs in production
- Use Azure Firewall or Network Security Groups with specific source IPs
- Enable HTTPS with SSL certificates
- Configure Windows Firewall on VMs
- Use Azure Private Link for SQL Database connectivity
- Implement Azure Application Gateway with WAF for additional security

## High Availability

- IIS instances run in an Azure Virtual Machine Scale Set with multiple fault/update domains
- Load Balancer distributes HTTP/HTTPS traffic across healthy instances
- Health probe monitors HTTP port 80
- Azure SQL Database provides built-in high availability (depending on SKU)

## Autoscaling

- Autoscale uses Azure Monitor rules tied to VMSS CPU percentage.
- Configure thresholds, steps, cooldowns, and metric windows via the autoscale variables.
- Notifications can be sent to any list of email addresses by populating `autoscale_notification_emails`.
- Disable autoscale by setting `autoscale_enabled = false`; VMSS will then stick to `autoscale_default_instances`.

## IIS Features Installed

The following IIS features are automatically installed on each VM:
- Web Server (IIS)
- IIS Management Console
- ASP.NET 4.5
- .NET Extensibility 4.5
- ISAPI Extensions
- ISAPI Filters

## Cost Optimization

- Use smaller VM sizes for non-production environments
- Choose appropriate SQL Database SKU (S0 for dev/test)
- Use Azure Reserved Instances for production workloads
- Review and delete resources when not in use
- Consider Azure App Service as an alternative for simpler web apps

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Troubleshooting

### Web application not accessible
- Check Load Balancer health probe status in Azure Portal
- Verify IIS is running on VMs (connect via RDP)
- Check Network Security Group rules
- Verify backend pool has healthy VMs

### SQL Database connection issues
- Verify SQL Database firewall rules allow your IP/subnet
- Check SQL Database status in Azure Portal
- Ensure connection string uses correct server FQDN
- Verify SQL admin credentials

### VMs not accessible
- Check Network Security Group rules
- Verify VM status in Azure Portal
- Check Windows Firewall rules on VMs

### Load Balancer not routing traffic
- Check health probe status
- Verify backend pool has healthy VMs
- Review Load Balancer rules configuration
- Ensure IIS default page is accessible on port 80

## Next Steps

- Deploy your web application to IIS
- Configure SSL certificates for HTTPS
- Set up Azure Application Gateway with WAF
- Configure Azure SQL Database backups
- Set up monitoring and alerts
- Implement Azure Backup for VMs
- Configure auto-scaling for VMs
- Set up Azure DevOps CI/CD pipelines
- Implement Azure Key Vault for secrets management
