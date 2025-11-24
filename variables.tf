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
  description = "Number of VMs to create"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Size of the VMs"
  type        = string
  default     = "Standard_DS2_v2"
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

