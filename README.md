# Azure IIS Web Servers with Azure SQL Database and Load Balancer - Terraform

This Terraform project provisions a highly available web infrastructure on Azure with:
- **Virtual Machine Scale Set** with Windows VMs running IIS (Internet Information Services)
- **Autoscaling** based on CPU metrics (configurable min/max instances)
- **Azure SQL Database** (cloud-managed SQL)
- **Azure Load Balancer** in front of the VMs for web traffic
- **Azure Key Vault** for secure secrets management
- **Network security group** with appropriate rules
- **High availability** through VM Scale Set distribution

## Architecture

```
Internet
   |
   v
[Load Balancer] (Public IP)
   |
   v
[VM Scale Set] (Auto-scaling: 2-10 instances)
   |
   +---> [VM Instance 1] (IIS Web Server)
   +---> [VM Instance 2] (IIS Web Server)
   +---> [VM Instance N] (IIS Web Server)
   |
   v
[Azure SQL Database]
   |
   v
[Azure Key Vault] (Secrets Management)
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
   - Adjust `location`, `vm_size` as needed
   - Configure autoscaling settings (min/max instances, CPU thresholds)
   - Configure Key Vault settings
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
| `vm_size` | VM size | `Standard_DS2_v2` |
| `windows_server_sku` | Windows Server SKU | `2022-Datacenter` |
| `admin_username` | VM admin username | *required* |
| `admin_password` | VM admin password | *required* |
| `autoscale_enabled` | Enable autoscaling | `true` |
| `autoscale_min_instances` | Minimum VM instances | `2` |
| `autoscale_max_instances` | Maximum VM instances | `10` |
| `autoscale_default_instances` | Default VM instances | `2` |
| `autoscale_scale_out_cpu_threshold` | CPU % to scale out | `75` |
| `autoscale_scale_in_cpu_threshold` | CPU % to scale in | `25` |
| `use_key_vault` | Use Key Vault for secrets | `true` |
| `key_vault_sku` | Key Vault SKU | `standard` |
| `key_vault_purge_protection` | Enable purge protection | `false` |
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

The VMs are in a private subnet. To connect via RDP:

1. **Option 1**: Use Azure Bastion (recommended for production)
   - Create an Azure Bastion resource
   - Connect through Azure Portal

2. **Option 2**: Create a VPN connection
   - Set up Azure VPN Gateway
   - Connect from your local machine

3. **Option 3**: Add a public IP to one VM temporarily (not recommended for production)
   - Modify the configuration to add a public IP
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

## High Availability and Autoscaling

- **VM Scale Set** automatically distributes VMs across fault and update domains
- **Autoscaling** automatically adds/removes VM instances based on CPU utilization:
  - Scales out when average CPU > 75% for 5 minutes
  - Scales in when average CPU < 25% for 5 minutes
  - Configurable min/max instances and thresholds
- **Load Balancer** distributes HTTP/HTTPS traffic across healthy VMs
- **Health probe** monitors HTTP port 80
- **Azure SQL Database** provides built-in high availability (depending on SKU)

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

## Azure Key Vault Integration

This project includes Azure Key Vault for secure secrets management:

- **Secrets stored in Key Vault**:
  - VM admin password
  - SQL admin password
  - VM admin username (reference)
  - SQL admin username (reference)

- **Access Control**:
  - Network ACLs restrict access to VNet (configurable)
  - Access policies control who can read/write secrets
  - Soft delete enabled (7 days retention)
  - Optional purge protection for production

- **Usage**:
  - Secrets are automatically stored during Terraform apply
  - Resources reference Key Vault secrets when `use_key_vault = true`
  - CI/CD pipelines can retrieve secrets from Key Vault

## Azure DevOps CI/CD

This project includes Azure DevOps pipeline configurations:

### Pipeline Files

- **`azure-pipelines.yml`**: Main CI/CD pipeline for infrastructure deployment
- **`azure-pipelines-pr.yml`**: Pull request validation pipeline

### Setup Instructions

See [`.azure-pipelines/README.md`](.azure-pipelines/README.md) for detailed setup instructions.

### Quick Setup

1. **Create Azure Service Connection** in Azure DevOps
2. **Create Variable Group** named `terraform-variables` with:
   - `azureServiceConnection`: Service connection name
   - `terraformBackendResourceGroup`: Resource group for state storage
   - `terraformBackendStorageAccount`: Storage account for state
   - `terraformBackendContainer`: Container name (e.g., `tfstate`)
   - `keyVaultName`: Key Vault name (optional)
3. **Create Terraform Backend Storage** (see `backend.tf.example`)
4. **Import Pipeline** from `azure-pipelines.yml`

### Pipeline Stages

1. **Validate**: Terraform init, validate, and format check
2. **Plan**: Create execution plan and publish as artifact
3. **Apply**: Apply changes (main branch only, requires approval)

## Next Steps

- Deploy your web application to IIS
- Configure SSL certificates for HTTPS
- Set up Azure Application Gateway with WAF
- Configure Azure SQL Database backups
- Set up monitoring and alerts
- Implement Azure Backup for VMs
- Configure additional autoscaling metrics (memory, network, etc.)
- Set up additional Key Vault secrets for application configuration
- Implement Azure DevOps release pipelines for application deployment
