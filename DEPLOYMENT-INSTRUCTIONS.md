# Application Deployment Instructions

This guide shows you how to deploy your application to the VM Scale Set using the best methods.

## 🚀 Quick Start: Azure Files Method (Recommended)

This is the **fastest and easiest** method - deploy once, all VMs see it automatically!

### Step 1: Enable App Storage in Terraform

Edit `terraform.tfvars` and add:

```hcl
enable_app_storage = true
app_storage_quota_gb = 100  # Adjust as needed
```

### Step 2: Apply Terraform Changes

```bash
terraform plan
terraform apply
```

This will create:
- Azure Storage Account for files
- Azure Files share
- Custom Script Extension to mount the share on all VMs

### Step 3: Upload Your Application

**Option A: Using Azure Portal**
1. Go to Azure Portal → Storage Accounts
2. Find your storage account (name starts with `iisappfiles`)
3. Click "File shares" → `appfiles`
4. Click "Upload" and upload your application files
5. Create an `app` folder and place your files there

**Option B: Using Azure CLI**
```bash
# Get storage account name
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null || echo "iisappfilesXXXXX")

# Upload files
az storage file upload \
  --account-name $STORAGE_ACCOUNT \
  --share-name appfiles \
  --source "C:\path\to\your\app\*" \
  --path "app/" \
  --recursive
```

**Option C: Using Azure Storage Explorer**
1. Download [Azure Storage Explorer](https://azure.microsoft.com/features/storage-explorer/)
2. Connect to your Azure account
3. Navigate to your storage account → File shares → `appfiles`
4. Create `app` folder and drag/drop your files

### Step 4: Verify Deployment

Access your application via the Load Balancer:
```bash
terraform output web_app_url
```

All VM instances will automatically serve files from the Azure Files share!

---

## 📦 Method 2: Blob Storage Deployment

For applications that need to be on local disk (faster performance).

### Step 1: Upload Application to Blob Storage

```bash
# Create container
az storage container create \
  --account-name migrationdata32 \
  --name app-deployments \
  --auth-mode login

# Upload your application (as ZIP file)
az storage blob upload \
  --account-name migrationdata32 \
  --container-name app-deployments \
  --name app.zip \
  --file "C:\path\to\your\app.zip" \
  --auth-mode login
```

### Step 2: Update Terraform Configuration

Edit `terraform.tfvars`:

```hcl
enable_app_storage = false  # Disable Azure Files
app_deployment_script_uris = [
  "https://migrationdata32.blob.core.windows.net/app-deployments/deploy-app-blob-storage.ps1"
]
```

### Step 3: Create Deployment Script

Upload `deploy-app-blob-storage.ps1` to your blob storage, then apply:

```bash
terraform apply
```

The script will download and deploy your application to all VM instances.

---

## 🔄 Method 3: Manual Deployment (For Testing)

If you need to test on a single VM first:

### Step 1: Get VM Instance IP

```bash
# List VM instances
az vmss list-instances \
  --resource-group rg-iis-sql-lb \
  --name iis-vmss \
  --query "[].{InstanceId:instanceId, PrivateIP:networkProfile.networkInterfaces[0].ipConfigurations[0].privateIpAddress}" \
  --output table
```

### Step 2: Connect via RDP

If public IPs are enabled:
```bash
# Get public IPs
az vmss list-instance-public-ips \
  --resource-group rg-iis-sql-lb \
  --name iis-vmss \
  --output table
```

Connect using RDP with:
- IP: (from above)
- Username: `vmadmin` (from terraform.tfvars)
- Password: (from terraform.tfvars)

### Step 3: Copy Files Manually

1. Copy files to `C:\inetpub\wwwroot\`
2. Test on that instance
3. If working, use Azure Files or Blob Storage method for all VMs

---

## 📋 Deployment Checklist

- [ ] Application files ready
- [ ] Database connection string configured
- [ ] Application tested locally
- [ ] Choose deployment method (Azure Files recommended)
- [ ] Update terraform.tfvars
- [ ] Run `terraform apply`
- [ ] Upload application files
- [ ] Test via Load Balancer URL
- [ ] Verify all VM instances are serving the app
- [ ] Monitor autoscaling behavior

---

## 🔧 Troubleshooting

### Files not appearing on VMs

1. **Check Azure Files mount:**
   ```powershell
   # Connect to a VM and check
   Get-PSDrive Z
   ```

2. **Remount Azure Files:**
   - The Custom Script Extension should handle this automatically
   - Or manually remount using the script in `deploy-app-azure-files.ps1`

### Application not loading

1. **Check IIS is running:**
   ```powershell
   Get-Service W3SVC
   ```

2. **Check application pool:**
   ```powershell
   Import-Module WebAdministration
   Get-WebAppPoolState -Name "DefaultAppPool"
   ```

3. **Check Load Balancer health:**
   - Go to Azure Portal → Load Balancer → Health probes
   - Verify all instances are healthy

### Files updated but changes not visible

- **Azure Files:** Changes should be immediate (may need IIS reset)
- **Blob Storage:** Need to redeploy using the script

---

## 💡 Best Practices

1. **Use Azure Files for:**
   - Shared content (images, static files)
   - Configuration files
   - Content that changes frequently

2. **Use Blob Storage for:**
   - Application binaries
   - Versioned deployments
   - Files that need to be on local disk

3. **Version Control:**
   - Tag your deployments in blob storage
   - Use different containers/folders for versions
   - Keep deployment scripts in source control

4. **Monitoring:**
   - Set up Application Insights
   - Monitor VM Scale Set metrics
   - Set up alerts for deployment failures

---

## 🎯 Next Steps

After deployment:
1. Set up CI/CD pipeline (Azure DevOps)
2. Configure SSL certificates
3. Set up monitoring and alerts
4. Configure automated backups
5. Review and optimize autoscaling rules

