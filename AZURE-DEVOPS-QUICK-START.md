# 🚀 Azure DevOps Quick Start

Get your CI/CD pipeline running in 5 minutes!

## ⚡ Quick Setup (5 Steps)

### 1. Create Service Connection (2 min)

Azure DevOps → Project Settings → Service connections → New → Azure Resource Manager

- Name: `AzureServiceConnection`
- Subscription: Your subscription
- Resource group: `rg-iis-sql-lb`
- Click **Save**

### 2. Create Variable Group (1 min)

Pipelines → Library → + Variable group → Name: `Azure-Infrastructure`

Add variables:
```
AzureServiceConnection = AzureServiceConnection
ResourceGroupName = rg-iis-sql-lb
VMSSName = iis-vmss
StorageAccountName = <get from: terraform output app_storage_account_name>
FileShareName = appfiles
LoadBalancerIP = <get from: terraform output load_balancer_public_ip>
```

### 3. Add Pipeline File (30 sec)

Copy `azure-pipelines-simple.yml` to your repository root.

### 4. Create Pipeline (1 min)

Pipelines → New pipeline → Your repo → Existing YAML file → Select `azure-pipelines-simple.yml`

### 5. Run Pipeline (30 sec)

Click **Run** → Watch it deploy! 🎉

---

## 📁 Which Pipeline File to Use?

| File | When to Use |
|------|-------------|
| `azure-pipelines-simple.yml` | ✅ **Start here!** Simple file deployment |
| `azure-pipelines.yml` | Full build + deploy (.NET apps) |
| `azure-pipelines-terraform.yml` | Infrastructure + app deployment |

---

## 🔄 How It Works

```
1. You push code → Pipeline triggers
2. Pipeline uploads files → Azure Files share
3. All VMs see files → Automatically (via mounted share)
4. IIS restarts → On all instances
5. Done! ✅
```

---

## 🎯 What Gets Deployed?

- Files from your `app/` folder (or `dist/`, `wwwroot/`)
- Uploaded to Azure Files share
- All VM instances serve from the same share
- New VMs (from autoscaling) automatically get access

---

## 🔧 Customize for Your App

### If your app is in a different folder:

Edit `azure-pipelines-simple.yml`, find this line:
```yaml
$appFolder = if (Test-Path "$sourcePath\app") { "$sourcePath\app" }
```

Add your folder:
```yaml
$appFolder = if (Test-Path "$sourcePath\your-folder") { "$sourcePath\your-folder" }
```

### If you need to build first:

Use `azure-pipelines.yml` instead and customize the build steps.

---

## ✅ Verify It Works

1. **Check pipeline logs** - Should show "Files uploaded successfully"
2. **Visit your app** - `http://<load-balancer-ip>`
3. **Check Azure Files** - Portal → Storage → File shares → appfiles → app

---

## 🐛 Common Issues

**"Storage account not found"**
→ Check `StorageAccountName` variable is correct

**"Authentication failed"**
→ Verify service connection is working

**"Files uploaded but not visible"**
→ Wait 30 seconds, then check again (IIS restart takes time)

---

## 📚 Full Documentation

See `AZURE-DEVOPS-SETUP.md` for detailed setup instructions.

---

## 🎉 That's It!

Your pipeline is now set up. Every time you push to `main`, it will automatically deploy to your VM Scale Set!

