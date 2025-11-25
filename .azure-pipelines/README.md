# Azure DevOps Pipelines

This directory contains Azure DevOps pipeline configurations for CI/CD.

## Pipeline Files

### azure-pipelines.yml
Main CI/CD pipeline that:
- Validates Terraform configuration
- Creates a Terraform plan
- Applies changes to production (only on main branch)

### azure-pipelines-pr.yml
Pull Request validation pipeline that:
- Validates Terraform configuration
- Creates a preview plan (no apply)

## Setup Instructions

### 1. Create Azure Service Connection

1. Go to **Project Settings** > **Service connections**
2. Create a new **Azure Resource Manager** service connection
3. Name it: `azureServiceConnection` (or update the variable in pipeline)
4. Use **Service principal (automatic)** or **Service principal (manual)**

### 2. Create Variable Group

1. Go to **Pipelines** > **Library**
2. Create a new variable group named: `terraform-variables`
3. Add the following variables:
   - `azureServiceConnection`: Name of your Azure service connection
   - `terraformBackendResourceGroup`: Resource group for Terraform state storage
   - `terraformBackendStorageAccount`: Storage account for Terraform state
   - `terraformBackendContainer`: Container name for Terraform state (e.g., `tfstate`)
   - `keyVaultName`: Name of your Azure Key Vault (optional, if using Key Vault)

### 3. Create Terraform Backend Storage (if not exists)

```bash
# Create resource group
az group create --name <resource-group-name> --location <location>

# Create storage account
az storage account create \
  --resource-group <resource-group-name> \
  --name <storage-account-name> \
  --sku Standard_LRS \
  --kind StorageV2

# Create container
az storage container create \
  --name tfstate \
  --account-name <storage-account-name>
```

### 4. Configure Terraform Backend

Add to your `main.tf` or create `backend.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "<resource-group-name>"
    storage_account_name = "<storage-account-name>"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
```

### 5. Grant Permissions

Ensure the service principal has:
- **Contributor** role on the subscription or resource group
- **Storage Blob Data Contributor** on the storage account (for state)
- **Key Vault Secrets User** (if using Key Vault for secrets)

### 6. Store Secrets in Key Vault

If using Azure Key Vault, store secrets:

```bash
az keyvault secret set \
  --vault-name <key-vault-name> \
  --name vm-admin-password \
  --value "<password>"

az keyvault secret set \
  --vault-name <key-vault-name> \
  --name sql-admin-password \
  --value "<password>"
```

### 7. Create Pipeline

1. Go to **Pipelines** > **Pipelines**
2. Click **New pipeline**
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Select `azure-pipelines.yml` from the root directory
6. Save and run

## Pipeline Stages

### Validate Stage
- Installs Terraform
- Initializes Terraform
- Validates configuration
- Checks formatting

### Plan Stage
- Creates Terraform execution plan
- Downloads secrets from Key Vault
- Publishes plan as artifact

### Apply Stage (Main branch only)
- Downloads plan artifact
- Applies Terraform changes
- Outputs results

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Use Azure Key Vault** for sensitive values
3. **Use variable groups** for non-sensitive configuration
4. **Enable branch policies** to require PR reviews
5. **Use approval gates** for production deployments
6. **Enable audit logging** for pipeline runs

## Troubleshooting

### Common Issues

1. **Service Connection Not Found**
   - Verify the service connection name matches the variable
   - Check service connection permissions

2. **Terraform Backend Access Denied**
   - Ensure service principal has Storage Blob Data Contributor role
   - Verify storage account and container exist

3. **Key Vault Access Denied**
   - Grant service principal Key Vault Secrets User role
   - Check Key Vault network ACLs allow Azure DevOps

4. **Terraform Plan Fails**
   - Check variable values in variable group
   - Verify all required secrets are in Key Vault
   - Review Terraform configuration for errors

