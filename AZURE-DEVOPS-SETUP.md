# Azure DevOps Integration Guide

This guide shows you how to integrate your VM Scale Set deployment with Azure DevOps for automated CI/CD pipelines.

## 📋 Prerequisites

1. **Azure DevOps Organization** - Create at https://dev.azure.com
2. **Azure Service Connection** - Connect Azure DevOps to your Azure subscription
3. **Repository** - Your code in Azure Repos, GitHub, or other Git repository

---

## 🔧 Step 1: Create Azure Service Connection

### In Azure DevOps:

1. Go to **Project Settings** → **Service connections**
2. Click **New service connection**
3. Select **Azure Resource Manager**
4. Choose **Workload Identity federation (automatic)** or **Service principal (automatic)**
5. Select your subscription and resource group
6. Name it: `AzureServiceConnection` (or your preferred name)
7. Click **Save**

### Verify Connection:

```bash
# Test the connection works
az login
az account show
```

---

## 🔧 Step 2: Create Variable Group

### In Azure DevOps:

1. Go to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name: `Azure-Infrastructure`
4. Add these variables:

| Variable Name | Value | Secret? |
|--------------|-------|---------|
| `AzureServiceConnection` | Name of your service connection | No |
| `ResourceGroupName` | `rg-iis-sql-lb` | No |
| `VMSSName` | `iis-vmss` | No |
| `StorageAccountName` | (Get from `terraform output app_storage_account_name`) | No |
| `FileShareName` | `appfiles` | No |
| `LoadBalancerIP` | (Get from `terraform output load_balancer_public_ip`) | No |
| `TerraformStateResourceGroup` | `rg-terraform-state` | No |
| `TerraformStateStorageAccount` | `tfstateXXXXX` | No |

5. Click **Save**

---

## 🔧 Step 3: Set Up Terraform State Backend (Optional but Recommended)

For team collaboration, store Terraform state in Azure Storage:

### Create Storage Account for State:

```bash
# Create resource group for state
az group create --name rg-terraform-state --location "East US"

# Create storage account
az storage account create \
  --name tfstate$(date +%s | cut -b1-10) \
  --resource-group rg-terraform-state \
  --location "East US" \
  --sku Standard_LRS

# Create container
az storage container create \
  --name terraform-state \
  --account-name <storage-account-name>
```

### Update Terraform Backend:

Create `backend.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstateXXXXX"  # Your storage account name
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"
  }
}
```

---

## 🔧 Step 4: Create Pipeline

### Option A: Application Deployment Only

Use `azure-pipelines.yml` if you only want to deploy applications (infrastructure already exists):

1. In Azure DevOps, go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Select `azure-pipelines.yml`
6. Click **Run**

### Option B: Infrastructure + Application

Use `azure-pipelines-terraform.yml` if you want to manage infrastructure AND deploy applications:

1. In Azure DevOps, go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Select `azure-pipelines-terraform.yml`
6. Click **Run**

---

## 🔧 Step 5: Configure Pipeline Variables

### Update Pipeline Variables:

1. Go to your pipeline → **Edit**
2. Click **Variables**
3. Add or update variables as needed
4. Link the variable group: `Azure-Infrastructure`

### Required Variables:

- `AzureServiceConnection` - Your service connection name
- `ResourceGroupName` - `rg-iis-sql-lb`
- `VMSSName` - `iis-vmss`
- `StorageAccountName` - Get from Terraform output
- `LoadBalancerIP` - Get from Terraform output

---

## 🚀 Step 6: Pipeline Workflow

### Typical Flow:

```
1. Code Push → Triggers Pipeline
2. Build Stage → Compiles application
3. Deploy Stage → Uploads to Azure Files
4. Verification → Tests application endpoint
```

### Manual Triggers:

You can also trigger manually:
- Go to **Pipelines** → Select your pipeline → **Run pipeline**

---

## 📝 Pipeline Customization

### For .NET Applications:

The pipeline includes .NET build steps. If you're not using .NET:

1. Remove or comment out:
   - `UseDotNet@2` task
   - `NuGetCommand@2` task
   - `VSBuild@1` task

2. Modify `ArchiveFiles@2` to package your application:
   ```yaml
   - task: ArchiveFiles@2
     inputs:
       rootFolderOrFile: '$(Build.SourcesDirectory)/your-app-folder'
       archiveFile: '$(Build.ArtifactStagingDirectory)/app.zip'
   ```

### For Node.js Applications:

Add Node.js tasks:
```yaml
- task: NodeTool@0
  inputs:
    versionSpec: '18.x'
    
- task: Npm@1
  inputs:
    command: 'install'
    
- task: Npm@1
  inputs:
    command: 'run build'
```

### For Static Websites:

Simply archive your static files:
```yaml
- task: ArchiveFiles@2
  inputs:
    rootFolderOrFile: '$(Build.SourcesDirectory)/dist'
    archiveFile: '$(Build.ArtifactStagingDirectory)/app.zip'
```

---

## 🔐 Security Best Practices

### 1. Use Variable Groups for Secrets

Never hardcode secrets in YAML files. Use:
- **Variable groups** with secret variables
- **Azure Key Vault** integration
- **Service connections** for authentication

### 2. Limit Service Principal Permissions

Your service connection should have:
- **Contributor** role on the resource group (minimum)
- **Storage Blob Data Contributor** for file uploads
- **Not** Owner or Subscription-level permissions

### 3. Use Environments

Create **Environments** in Azure DevOps:
- **Development** - Auto-approve
- **Staging** - Manual approval
- **Production** - Manual approval + multiple reviewers

---

## 📊 Monitoring and Notifications

### Set Up Notifications:

1. Go to **Project Settings** → **Notifications**
2. Create subscription for:
   - Pipeline failures
   - Deployment completions
   - Approval requests

### View Pipeline Runs:

- **Pipelines** → Your pipeline → **Runs**
- See logs, artifacts, and test results
- Download deployment artifacts

---

## 🔄 Deployment Strategies

### Blue-Green Deployment:

1. Deploy to new Azure Files share
2. Update VM Scale Set to point to new share
3. Verify new deployment
4. Switch traffic
5. Remove old share

### Rolling Deployment:

The current setup does rolling deployments automatically:
- Files updated in Azure Files
- All VMs gradually pick up changes
- Load balancer distributes traffic

### Canary Deployment:

1. Deploy to subset of VMs first
2. Monitor metrics
3. Gradually roll out to all VMs

---

## 🐛 Troubleshooting

### Pipeline Fails on Upload:

**Error**: "Storage account not found"
- **Solution**: Verify `StorageAccountName` variable is correct
- Get it: `terraform output app_storage_account_name`

### Pipeline Fails on Authentication:

**Error**: "Authentication failed"
- **Solution**: 
  1. Verify service connection is valid
  2. Check service principal has correct permissions
  3. Re-authenticate service connection

### Application Not Updating:

**Error**: "Files uploaded but changes not visible"
- **Solution**:
  1. Add IIS reset step to pipeline
  2. Check file permissions in Azure Files
  3. Verify junction point is working

### Terraform State Locked:

**Error**: "Error acquiring the state lock"
- **Solution**:
  1. Check if another pipeline is running
  2. Manually unlock: `terraform force-unlock <LOCK_ID>`
  3. Use state backend (recommended)

---

## 📚 Additional Resources

- [Azure DevOps Documentation](https://docs.microsoft.com/azure/devops/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Files Documentation](https://docs.microsoft.com/azure/storage/files/)
- [VM Scale Set Deployment](https://docs.microsoft.com/azure/virtual-machine-scale-sets/)

---

## ✅ Quick Checklist

- [ ] Azure DevOps organization created
- [ ] Service connection configured
- [ ] Variable group created with all variables
- [ ] Pipeline YAML file added to repository
- [ ] Pipeline created and tested
- [ ] Terraform state backend configured (optional)
- [ ] Notifications configured
- [ ] Environments set up (optional)
- [ ] First deployment successful

---

## 🎯 Next Steps

1. **Set up the pipeline** using the steps above
2. **Test with a small change** to verify it works
3. **Configure branch policies** for production deployments
4. **Set up monitoring** and alerts
5. **Document your deployment process** for your team

Need help? Check the troubleshooting section or review the pipeline YAML files for customization options.

