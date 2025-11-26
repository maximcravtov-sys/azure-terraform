output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "load_balancer_public_ip" {
  description = "Public IP address of the Load Balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "load_balancer_id" {
  description = "ID of the Load Balancer"
  value       = azurerm_lb.main.id
}

output "vmss_id" {
  description = "ID of the Virtual Machine Scale Set"
  value       = azurerm_windows_virtual_machine_scale_set.main.id
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = azurerm_windows_virtual_machine_scale_set.main.name
}

output "vmss_instance_count" {
  description = "Current number of instances in the VM Scale Set"
  value       = azurerm_windows_virtual_machine_scale_set.main.instances
}

output "autoscaling_enabled" {
  description = "Whether autoscaling is enabled"
  value       = var.autoscale_enabled
}

output "autoscaling_min_instances" {
  description = "Minimum number of VM instances"
  value       = var.autoscale_min_instances
}

output "autoscaling_max_instances" {
  description = "Maximum number of VM instances"
  value       = var.autoscale_max_instances
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL Server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the Azure SQL Database"
  value       = azurerm_mssql_database.main.name
}

output "sql_connection_string_template" {
  description = "Template for Azure SQL Database connection string"
  value       = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=<your-password>;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  sensitive   = true
}

output "web_app_url" {
  description = "URL to access the web application via Load Balancer"
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

output "rdp_connection_info" {
  description = "RDP connection information for VM Scale Set"
  value = {
    vmss_name   = azurerm_windows_virtual_machine_scale_set.main.name
    public_ip   = azurerm_public_ip.lb.ip_address
    username    = var.admin_username
    note        = "Use Azure Bastion or VPN to connect via RDP. Connect to individual instances through the load balancer."
    autoscaling = var.autoscale_enabled ? "Enabled (${var.autoscale_min_instances}-${var.autoscale_max_instances} instances)" : "Disabled"
  }
  sensitive = true
}

