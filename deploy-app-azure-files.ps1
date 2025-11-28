# PowerShell script to mount Azure Files and deploy application
# This script runs on each VM instance via Custom Script Extension

param(
    [string]$StorageAccountName = $env:STORAGE_ACCOUNT_NAME,
    [string]$StorageAccountKey = $env:STORAGE_ACCOUNT_KEY,
    [string]$FileShareName = $env:FILE_SHARE_NAME,
    [string]$DriveLetter = "Z",
    [string]$IISPath = "C:\inetpub\wwwroot"
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Azure Files Mount and App Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check if drive is already mounted
function Test-AzureFileShare {
    param([string]$Drive)
    $drive = Get-PSDrive -Name $Drive -ErrorAction SilentlyContinue
    return $drive -ne $null
}

# Mount Azure Files Share
Write-Host "Mounting Azure Files share..." -ForegroundColor Green

if (Test-AzureFileShare -Drive $DriveLetter) {
    Write-Host "Drive $DriveLetter is already mounted. Unmounting first..." -ForegroundColor Yellow
    net use "${DriveLetter}:" /delete /y
}

# Create credential for Azure Files
$secureKey = ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("Azure\$StorageAccountName", $secureKey)

# Mount the file share
$uncPath = "\\$StorageAccountName.file.core.windows.net\$FileShareName"
New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $uncPath -Credential $credential -Persist

if (Test-AzureFileShare -Drive $DriveLetter) {
    Write-Host "Successfully mounted Azure Files share to ${DriveLetter}:\" -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to mount Azure Files share!" -ForegroundColor Red
    exit 1
}

# Create symbolic link or copy files to IIS directory
Write-Host ""
Write-Host "Setting up application files..." -ForegroundColor Green

# Option 1: Create symbolic link (recommended - files stay on Azure Files)
Write-Host "Creating symbolic link from IIS to Azure Files..." -ForegroundColor Yellow

# Backup existing wwwroot if it exists and has content
if (Test-Path $IISPath -PathType Container) {
    $backupPath = "$IISPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    if ((Get-ChildItem $IISPath -Force | Measure-Object).Count -gt 0) {
        Write-Host "Backing up existing wwwroot to $backupPath" -ForegroundColor Yellow
        Move-Item -Path $IISPath -Destination $backupPath -Force
    } else {
        Remove-Item -Path $IISPath -Force -ErrorAction SilentlyContinue
    }
}

# Create new wwwroot directory
New-Item -Path $IISPath -ItemType Directory -Force | Out-Null

# Create symbolic link (requires admin privileges, which we have)
$appPath = "${DriveLetter}:\app"
if (-not (Test-Path $appPath)) {
    Write-Host "Creating app directory in Azure Files share..." -ForegroundColor Yellow
    New-Item -Path $appPath -ItemType Directory -Force | Out-Null
    
    # Create a default index.html if app directory is empty
    $defaultHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Application Deployment</title>
</head>
<body>
    <h1>Application Deployment Ready</h1>
    <p>Deploy your application files to: ${DriveLetter}:\app</p>
    <p>All VM instances will automatically see the files.</p>
    <p>Server: $env:COMPUTERNAME</p>
</body>
</html>
"@
    Set-Content -Path "$appPath\index.html" -Value $defaultHtml
}

# Create junction point (works better than symlink for network shares)
Write-Host "Creating junction point..." -ForegroundColor Yellow
cmd /c mklink /J "$IISPath\app" "$appPath"

# Alternative: Copy files (if you prefer local copies)
# Write-Host "Copying files from Azure Files to IIS directory..." -ForegroundColor Yellow
# Copy-Item -Path "${DriveLetter}:\app\*" -Destination $IISPath -Recurse -Force

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Azure Files mounted at: ${DriveLetter}:\" -ForegroundColor Green
Write-Host "Application files location: ${DriveLetter}:\app" -ForegroundColor Green
Write-Host "IIS serving from: $IISPath" -ForegroundColor Green
Write-Host ""
Write-Host "To deploy your application:" -ForegroundColor Yellow
Write-Host "1. Upload files to Azure Files share (container: $FileShareName)" -ForegroundColor White
Write-Host "2. Place files in the 'app' folder" -ForegroundColor White
Write-Host "3. All VM instances will automatically see the updated files" -ForegroundColor White
Write-Host ""

