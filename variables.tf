variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-iis-sql-lb"
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "East US"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "iis"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vm_count" {
  description = "Initial number of VMs (deprecated - use autoscaling min/max instead)"
  type        = number
  default     = 2
}

variable "autoscale_min_instances" {
  description = "Minimum number of VM instances in the scale set"
  type        = number
  default     = 2
}

variable "autoscale_max_instances" {
  description = "Maximum number of VM instances in the scale set"
  type        = number
  default     = 10
}

variable "autoscale_default_instances" {
  description = "Default number of VM instances in the scale set"
  type        = number
  default     = 2
}

variable "autoscale_enabled" {
  description = "Enable autoscaling for the VM scale set"
  type        = bool
  default     = true
}

variable "autoscale_scale_out_cpu_threshold" {
  description = "CPU percentage threshold to trigger scale out"
  type        = number
  default     = 75
}

variable "autoscale_scale_in_cpu_threshold" {
  description = "CPU percentage threshold to trigger scale in"
  type        = number
  default     = 25
}

variable "autoscale_scale_out_step" {
  description = "Number of instances to add when scaling out"
  type        = number
  default     = 1
}

variable "autoscale_scale_in_step" {
  description = "Number of instances to remove when scaling in"
  type        = number
  default     = 1
}

variable "autoscale_scale_out_cooldown" {
  description = "Cooldown period after a scale-out event (ISO 8601 duration)"
  type        = string
  default     = "PT5M"
}

variable "autoscale_scale_in_cooldown" {
  description = "Cooldown period after a scale-in event (ISO 8601 duration)"
  type        = string
  default     = "PT5M"
}

variable "autoscale_metric_time_grain" {
  description = "Granularity for collecting autoscale metrics (ISO 8601 duration)"
  type        = string
  default     = "PT1M"
}

variable "autoscale_metric_time_window" {
  description = "Observation window for autoscale metrics (ISO 8601 duration)"
  type        = string
  default     = "PT5M"
}

variable "autoscale_notification_emails" {
  description = "Email recipients to notify when autoscale actions occur"
  type        = list(string)
  default     = []
}

variable "vm_size" {
  description = "Size of the VMs"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "vmss_enable_public_ip" {
  description = "Enable public IP addresses for VM Scale Set instances"
  type        = bool
  default     = false
}

variable "vmss_public_ip_prefix_length" {
  description = "Prefix length for the Public IP Prefix (e.g., 30 for /30 = 4 IPs, 28 for /28 = 16 IPs)"
  type        = number
  default     = 30
}

variable "admin_username" {
  description = "Administrator username for the VMs"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Administrator password for the VMs"
  type        = string
  sensitive   = true
}

variable "windows_server_sku" {
  description = "Windows Server SKU"
  type        = string
  default     = "2022-Datacenter"
}

variable "sql_server_version" {
  description = "Azure SQL Server version"
  type        = string
  default     = "12.0"
}

variable "sql_admin_username" {
  description = "Administrator username for Azure SQL Server"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "Administrator password for Azure SQL Server"
  type        = string
  sensitive   = true
}

variable "sql_database_name" {
  description = "Name of the Azure SQL Database"
  type        = string
  default     = "appdb"
}

variable "sql_database_sku" {
  description = "Azure SQL Database SKU (e.g., S0, S1, P1, GP_Gen5_2)"
  type        = string
  default     = "S0"
}

variable "sql_database_max_size_gb" {
  description = "Maximum size of the Azure SQL Database in GB"
  type        = number
  default     = 2
}

variable "sql_database_zone_redundant" {
  description = "Enable zone redundancy for Azure SQL Database"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "IIS-SQL-HA"
  }
}

