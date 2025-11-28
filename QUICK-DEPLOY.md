# 🚀 Quick Deployment Guide

## The Fastest Way: Azure Files (Recommended)

### 1. Enable in Terraform (30 seconds)

Edit `terraform.tfvars`:
```hcl
enable_app_storage = true
app_storage_quota_gb = 100
```

### 2. Apply Changes (2 minutes)
```bash
terraform apply
```

### 3. Upload Your App (1 minute)

**Using Azure Portal:**
1. Portal → Storage Accounts → Find `iisappfilesXXXXX`
2. File shares → `appfiles` → Upload
3. Create `app` folder, upload your files there

**Using Azure CLI:**
```bash
# Get storage account name
az storage account list --resource-group rg-iis-sql-lb --query "[?contains(name, 'appfiles')].name" -o tsv

# Upload files
az storage file upload-batch \
  --account-name <storage-account-name> \
  --share-name appfiles \
  --source "C:\path\to\your\app" \
  --destination "app" \
  --auth-mode login
```

### 4. Done! ✅

Your app is now live on ALL VM instances automatically!

Access it: `http://<load-balancer-ip>`

---

## Why This is Better Than Copying to Each Server

| Method | Time | Effort | Works with Autoscaling |
|--------|------|--------|----------------------|
| **Azure Files** | ⭐ 1 min | ⭐ Upload once | ✅ Yes - automatic |
| Copy to each VM | ❌ 10+ min | ❌ Manual per VM | ❌ No - new VMs miss it |

---

## What Happens Automatically

1. ✅ Azure Files share created
2. ✅ Share mounted on ALL VM instances (Z: drive)
3. ✅ IIS configured to serve from Z:\app
4. ✅ New VMs (from autoscaling) automatically get access
5. ✅ Update files once → all VMs see changes instantly

---

## Need Help?

See `DEPLOYMENT-INSTRUCTIONS.md` for detailed steps and troubleshooting.

