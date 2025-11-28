# PowerShell script to deploy application from Azure Blob Storage
# This script downloads files from blob storage and deploys to IIS

param(
    [string]$StorageAccountName = "",
    [string]$ContainerName = "app-deployments",
    [string]$BlobName = "app.zip",
    [string]$IISPath = "C:\inetpub\wwwroot",
    [string]$TempPath = "C:\temp"
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Application Deployment from Blob Storage" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Create temp directory
if (-not (Test-Path $TempPath)) {
    New-Item -Path $TempPath -ItemType Directory -Force | Out-Null
}

# Download file from blob storage
Write-Host "Downloading application from blob storage..." -ForegroundColor Green
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Yellow
Write-Host "Container: $ContainerName" -ForegroundColor Yellow
Write-Host "Blob: $BlobName" -ForegroundColor Yellow
Write-Host ""

# Get storage account key (requires Azure CLI or use managed identity)
try {
    $storageKey = (az storage account keys list --account-name $StorageAccountName --query "[0].value" -o tsv)
    
    if ([string]::IsNullOrEmpty($storageKey)) {
        Write-Host "ERROR: Could not retrieve storage account key!" -ForegroundColor Red
        Write-Host "Make sure Azure CLI is installed and you're logged in (az login)" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "ERROR: Failed to get storage account key. Error: $_" -ForegroundColor Red
    exit 1
}

# Download blob
$downloadPath = Join-Path $TempPath $BlobName
Write-Host "Downloading to: $downloadPath" -ForegroundColor Yellow

az storage blob download `
    --account-name $StorageAccountName `
    --container-name $ContainerName `
    --name $BlobName `
    --file $downloadPath `
    --account-key $storageKey

if (-not (Test-Path $downloadPath)) {
    Write-Host "ERROR: Failed to download blob!" -ForegroundColor Red
    exit 1
}

Write-Host "Download completed successfully!" -ForegroundColor Green
Write-Host ""

# Extract if it's a zip file
$fileExtension = [System.IO.Path]::GetExtension($BlobName).ToLower()

if ($fileExtension -eq ".zip") {
    Write-Host "Extracting ZIP file..." -ForegroundColor Green
    
    # Backup existing wwwroot
    if (Test-Path $IISPath) {
        $backupPath = "$IISPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        if ((Get-ChildItem $IISPath -Force | Measure-Object).Count -gt 0) {
            Write-Host "Backing up existing wwwroot to $backupPath" -ForegroundColor Yellow
            Move-Item -Path $IISPath -Destination $backupPath -Force
        } else {
            Remove-Item -Path $IISPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Create new wwwroot
    New-Item -Path $IISPath -ItemType Directory -Force | Out-Null
    
    # Extract ZIP
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $IISPath)
    
    Write-Host "Extraction completed!" -ForegroundColor Green
} else {
    # Copy file directly
    Write-Host "Copying file to IIS directory..." -ForegroundColor Green
    Copy-Item -Path $downloadPath -Destination $IISPath -Force
}

# Clean up temp file
Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue

# Restart IIS to pick up changes
Write-Host ""
Write-Host "Restarting IIS..." -ForegroundColor Green
iisreset

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application deployed to: $IISPath" -ForegroundColor Green
Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Green
Write-Host ""

