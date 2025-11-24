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

output "vm_private_ips" {
  description = "Private IP addresses of the VMs"
  value       = azurerm_network_interface.vm[*].private_ip_address
}

output "vm_names" {
  description = "Names of the VMs"
  value       = azurerm_windows_virtual_machine.main[*].name
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
  description = "RDP connection information for VMs"
  value = {
    for idx, vm in azurerm_windows_virtual_machine.main : vm.name => {
      public_ip    = azurerm_public_ip.lb.ip_address
      private_ip   = azurerm_network_interface.vm[idx].private_ip_address
      username     = var.admin_username
      note         = "Use Azure Bastion or VPN to connect via RDP"
    }
  }
}

