# Autoscale Troubleshooting Guide

## Current Status

Based on the diagnostic check:

- **Current Capacity**: 2 instances
- **Minimum Instances**: 2 instances  
- **Scale-In Threshold**: CPU < 25% for 5 minutes
- **Current Average CPU**: 24.23% (below threshold)

## ❌ Why Instances Are NOT Scaling Down

### **Primary Reason: Already at Minimum**

Your VM Scale Set is currently at **2 instances**, which is also your **minimum** setting. Autoscale **cannot scale down below the minimum**, so it will not remove any instances.

```
Current: 2 instances
Minimum: 2 instances
Result:  Cannot scale down (already at minimum)
```

## How Autoscale Scale-In Works

For autoscale to scale down, ALL of these conditions must be met:

1. ✅ **Not at minimum** - Current capacity > minimum instances
2. ✅ **CPU below threshold** - Average CPU < 25% for 5 minutes
3. ✅ **Time window met** - CPU consistently low for the full 5-minute window
4. ✅ **Cooldown passed** - At least 5 minutes since last scale action

## Solutions

### Option 1: Lower the Minimum (If You Want Fewer Instances)

If you want to allow scaling down to 1 instance:

1. Edit `terraform.tfvars`:
```hcl
autoscale_min_instances = 1
```

2. Apply changes:
```bash
terraform apply
```

**Note**: This reduces your high availability. With only 1 instance, you lose redundancy.

### Option 2: Increase Scale-In Threshold (More Aggressive Scale-Down)

If CPU is consistently low but hovering around 25%, increase the threshold:

1. Edit `terraform.tfvars`:
```hcl
autoscale_scale_in_cpu_threshold = 30  # Was 25
```

2. Apply changes:
```bash
terraform apply
```

This makes autoscale more likely to scale down when CPU is low.

### Option 3: Reduce Time Window (Faster Scale-Down)

Make autoscale react faster to low CPU:

1. Edit `terraform.tfvars`:
```hcl
autoscale_metric_time_window = "PT3M"  # Was PT5M (5 minutes)
```

2. Apply changes:
```bash
terraform apply
```

**Warning**: Shorter windows can cause more frequent scaling, which may not be desired.

### Option 4: Manual Scale-Down (For Testing)

To manually reduce instances for testing:

```bash
az vmss scale \
  --resource-group rg-iis-sql-lb \
  --name iis-vmss \
  --new-capacity 1
```

**Note**: This bypasses autoscale. Autoscale will still try to maintain the configured minimum.

## Understanding Your Current Configuration

```hcl
autoscale_min_instances           = 2  # ← This prevents scaling below 2
autoscale_max_instances           = 10
autoscale_scale_in_cpu_threshold  = 25 # CPU must be < 25%
autoscale_metric_time_window      = "PT5M"  # For 5 minutes
autoscale_scale_in_cooldown       = "PT5M"  # Wait 5 min between actions
```

## Diagnostic Commands

### Check Current Status
```bash
az vmss show --resource-group rg-iis-sql-lb --name iis-vmss --query "sku.capacity" -o tsv
```

### Check Autoscale Settings
```bash
az monitor autoscale show \
  --resource-group rg-iis-sql-lb \
  --name iis-vmss-autoscale \
  --query "profiles[0].{Min:capacity.minimum, Max:capacity.maximum, Rules:rules[*].{Direction:scaleAction.direction, Threshold:metricTrigger.threshold}}" \
  --output json
```

### Check CPU Metrics
```bash
$vmssId = (az vmss show --resource-group rg-iis-sql-lb --name iis-vmss --query id -o tsv)
az monitor metrics list \
  --resource $vmssId \
  --metric "Percentage CPU" \
  --start-time (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ssZ") \
  --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") \
  --interval PT5M \
  --aggregation Average \
  --query "value[0].timeseries[0].data[-1].average" \
  -o tsv
```

### Run Full Diagnostic
```bash
powershell -ExecutionPolicy Bypass -File .\check-autoscale.ps1
```

## Common Issues

### Issue: "CPU is low but not scaling down"

**Possible Causes:**
1. At minimum instances (most common)
2. CPU not consistently below threshold for full time window
3. Cooldown period hasn't passed
4. Recent scale action (scale-out or scale-in) within cooldown period

### Issue: "Scaling down too aggressively"

**Solutions:**
- Increase `autoscale_scale_in_cpu_threshold`
- Increase `autoscale_metric_time_window`
- Increase `autoscale_scale_in_cooldown`

### Issue: "Not scaling down fast enough"

**Solutions:**
- Decrease `autoscale_metric_time_window`
- Decrease `autoscale_scale_in_cooldown`
- Increase `autoscale_scale_in_cpu_threshold` (makes it trigger sooner)

## Best Practices

1. **Minimum Instances**: Keep at least 2 for high availability
2. **Time Window**: 5 minutes is a good balance (not too sensitive, not too slow)
3. **Cooldown**: 5 minutes prevents rapid scaling oscillations
4. **Thresholds**: Keep scale-in threshold lower than scale-out (e.g., 25% vs 75%) to prevent flapping

## Monitoring

View autoscale activity in Azure Portal:
- Go to **Monitor** → **Autoscale**
- Select your autoscale setting
- View **Run history** to see scale actions
- Check **Metrics** to see CPU trends

## Next Steps

1. **Decide on minimum instances** - Do you need 2 for HA, or can you go to 1?
2. **Review CPU patterns** - Is CPU consistently low enough?
3. **Adjust thresholds** - Fine-tune based on your workload
4. **Monitor and iterate** - Watch autoscale behavior and adjust as needed

