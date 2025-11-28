# Script to diagnose autoscaling issues

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Autoscale Diagnostic Tool" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Get VMSS details
$resourceGroup = "rg-iis-sql-lb"
$vmssName = "iis-vmss"
$autoscaleName = "iis-vmss-autoscale"

Write-Host "1. Checking VM Scale Set Status..." -ForegroundColor Green
$vmss = az vmss show --resource-group $resourceGroup --name $vmssName --output json | ConvertFrom-Json
$currentCapacity = $vmss.sku.capacity
Write-Host "   Current capacity: $currentCapacity instances" -ForegroundColor Yellow

# Get autoscale settings
Write-Host ""
Write-Host "2. Checking Autoscale Configuration..." -ForegroundColor Green
$autoscale = az monitor autoscale show --resource-group $resourceGroup --name $autoscaleName --output json | ConvertFrom-Json
$minInstances = $autoscale.profiles[0].capacity.minimum
$maxInstances = $autoscale.profiles[0].capacity.maximum
$defaultInstances = $autoscale.profiles[0].capacity.default

Write-Host "   Minimum instances: $minInstances" -ForegroundColor Yellow
Write-Host "   Maximum instances: $maxInstances" -ForegroundColor Yellow
Write-Host "   Default instances: $defaultInstances" -ForegroundColor Yellow
Write-Host "   Autoscale enabled: $($autoscale.enabled)" -ForegroundColor Yellow

# Get scale-in rule
$scaleInRule = $autoscale.profiles[0].rules | Where-Object { $_.scaleAction.direction -eq "Decrease" }
if ($scaleInRule) {
    $scaleInThreshold = $scaleInRule.metricTrigger.threshold
    $scaleInCooldown = $scaleInRule.scaleAction.cooldown
    $scaleInWindow = $scaleInRule.metricTrigger.timeWindow
    Write-Host ""
    Write-Host "3. Scale-In Rule Configuration..." -ForegroundColor Green
    Write-Host "   Metric: $($scaleInRule.metricTrigger.metricName)" -ForegroundColor Yellow
    Write-Host "   Condition: CPU < $scaleInThreshold% for $scaleInWindow" -ForegroundColor Yellow
    Write-Host "   Action: Remove $($scaleInRule.scaleAction.value) instance(s)" -ForegroundColor Yellow
    Write-Host "   Cooldown: $scaleInCooldown" -ForegroundColor Yellow
}

# Check if at minimum
Write-Host ""
if ($currentCapacity -le $minInstances) {
    Write-Host "⚠️  WARNING: Already at minimum capacity ($minInstances instances)" -ForegroundColor Red
    Write-Host "   Autoscale will NOT scale down below the minimum." -ForegroundColor Yellow
} else {
    Write-Host "✓ Not at minimum - can scale down" -ForegroundColor Green
}

# Get CPU metrics
Write-Host ""
Write-Host "4. Checking CPU Metrics (last 2 hours)..." -ForegroundColor Green
$vmssId = $vmss.id
$endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$startTime = (Get-Date).AddHours(-2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$metrics = az monitor metrics list `
    --resource $vmssId `
    --metric "Percentage CPU" `
    --start-time $startTime `
    --end-time $endTime `
    --interval PT1M `
    --aggregation Average `
    --output json | ConvertFrom-Json

if ($metrics.value -and $metrics.value[0].timeseries -and $metrics.value[0].timeseries[0].data) {
    $cpuData = $metrics.value[0].timeseries[0].data | Where-Object { $_.average -ne $null }
    $avgCpu = ($cpuData | Measure-Object -Property average -Average).Average
    $minCpu = ($cpuData | Measure-Object -Property average -Minimum).Minimum
    $maxCpu = ($cpuData | Measure-Object -Property average -Maximum).Maximum
    $belowThreshold = ($cpuData | Where-Object { $_.average -lt $scaleInThreshold }).Count
    
    Write-Host "   Average CPU: $([math]::Round($avgCpu, 2))%" -ForegroundColor Yellow
    Write-Host "   Minimum CPU: $([math]::Round($minCpu, 2))%" -ForegroundColor Yellow
    Write-Host "   Maximum CPU: $([math]::Round($maxCpu, 2))%" -ForegroundColor Yellow
    $thresholdPercent = "$scaleInThreshold%"
    Write-Host "   Data points below threshold ($thresholdPercent): $belowThreshold out of $($cpuData.Count)" -ForegroundColor Yellow
    
    if ($avgCpu -ge $scaleInThreshold) {
        Write-Host ""
        Write-Host "⚠️  CPU is ABOVE scale-in threshold ($thresholdPercent)" -ForegroundColor Red
        Write-Host "   Autoscale will NOT scale down until CPU stays below $thresholdPercent for $scaleInWindow" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "✓ CPU is below threshold, but may not have been consistent for the required time window" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ⚠️  Could not retrieve CPU metrics" -ForegroundColor Red
}

# Check for recent scale actions
Write-Host ""
Write-Host "5. Checking Recent Scale Actions..." -ForegroundColor Green
$activityLogs = az monitor activity-log list `
    --resource-group $resourceGroup `
    --max-events 50 `
    --query "[?contains(operationName.value, 'autoscale') || contains(operationName.value, 'scale') || contains(operationName.value, 'VMSS')].{Time:eventTimestamp, Operation:operationName.value, Status:status.value}" `
    --output json | ConvertFrom-Json

if ($activityLogs) {
    Write-Host "   Recent scale-related operations:" -ForegroundColor Yellow
    $activityLogs | Select-Object -First 5 | ForEach-Object {
        $time = [DateTime]::Parse($_.Time).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "   - $time : $($_.Operation) - $($_.Status)" -ForegroundColor White
    }
} else {
    Write-Host "   No recent scale operations found" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($currentCapacity -le $minInstances) {
    Write-Host "❌ CANNOT SCALE DOWN: Already at minimum ($minInstances instances)" -ForegroundColor Red
} elseif ($avgCpu -ge $scaleInThreshold) {
    $cpuPercent = "$([math]::Round($avgCpu, 2))%"
    $thresholdPercent = "$scaleInThreshold%"
    Write-Host "❌ CANNOT SCALE DOWN: CPU ($cpuPercent) is above threshold ($thresholdPercent)" -ForegroundColor Red
    Write-Host "   Wait for CPU to drop below $thresholdPercent for $scaleInWindow" -ForegroundColor Yellow
} else {
    Write-Host "✓ Conditions met for potential scale-down" -ForegroundColor Green
    Write-Host "   However, autoscale evaluates continuously and may be waiting for:" -ForegroundColor Yellow
    Write-Host "   - Consistent low CPU for the full time window ($scaleInWindow)" -ForegroundColor Yellow
    Write-Host "   - Cooldown period to pass: $scaleInCooldown" -ForegroundColor Yellow
}

Write-Host ""

