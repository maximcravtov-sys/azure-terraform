terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Subnet
resource "azurerm_subnet" "main" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefix]

  # Enable service endpoint for SQL Server to allow VNet rules
  service_endpoints = ["Microsoft.Sql"]
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow RDP
  security_rule {
    name                       = "AllowRDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow Load Balancer health probe
  security_rule {
    name                       = "AllowHealthProbe"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "lb" {
  name                = "${var.prefix}-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Public IP Prefix for VM Scale Set instances
resource "azurerm_public_ip_prefix" "vmss" {
  count               = var.vmss_enable_public_ip ? 1 : 0
  name                = "${var.prefix}-vmss-pip-prefix"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  prefix_length       = var.vmss_public_ip_prefix_length
  sku                 = "Standard"
  zones               = []

  tags = var.tags
}

# Load Balancer
resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${var.prefix}-lb-frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }

  tags = var.tags
}

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "${var.prefix}-lb-backend-pool"
}

# Health Probe for HTTP
resource "azurerm_lb_probe" "http" {
  loadbalancer_id     = azurerm_lb.main.id
  name                = "${var.prefix}-lb-probe-http"
  port                = 80
  protocol            = "Http"
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load Balancer Rule for HTTP
resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "${var.prefix}-lb-rule-http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "${var.prefix}-lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.http.id
  idle_timeout_in_minutes        = 4
  load_distribution              = "Default"
}

# Load Balancer Rule for HTTPS
resource "azurerm_lb_rule" "https" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "${var.prefix}-lb-rule-https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "${var.prefix}-lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.http.id
  idle_timeout_in_minutes        = 4
  load_distribution              = "Default"
}

# Virtual Machine Scale Set
resource "azurerm_windows_virtual_machine_scale_set" "main" {
  name                = "${var.prefix}-vmss"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.vm_size
  instances           = var.autoscale_default_instances
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_server_sku
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${var.prefix}-vmss-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.main.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.main.id]

      # Public IP configuration for each VM instance
      dynamic "public_ip_address" {
        for_each = var.vmss_enable_public_ip ? [1] : []
        content {
          name                    = "${var.prefix}-vmss-pip"
          public_ip_prefix_id     = azurerm_public_ip_prefix.vmss[0].id
          idle_timeout_in_minutes = 4
        }
      }
    }
  }

  # Enable automatic OS upgrades
  upgrade_mode = "Automatic"

  # Health extension for better load balancer integration
  extension {
    name                       = "HealthExtension"
    publisher                  = "Microsoft.ManagedServices"
    type                       = "ApplicationHealthWindows"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true

    settings = jsonencode({
      protocol    = "http"
      port        = 80
      requestPath = "/"
    })
  }

  # IIS Installation Extension
  extension {
    name                       = "${var.prefix}-iis"
    publisher                  = "Microsoft.Compute"
    type                       = "CustomScriptExtension"
    type_handler_version       = "1.10"
    auto_upgrade_minor_version = true

    settings = jsonencode({
      commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Install-WindowsFeature -Name Web-Mgmt-Console; Install-WindowsFeature -Name Web-Asp-Net45; Install-WindowsFeature -Name Web-Net-Ext45; Install-WindowsFeature -Name Web-ISAPI-Ext; Install-WindowsFeature -Name Web-ISAPI-Filter; $hostname = hostname; New-Item -Path 'C:\\inetpub\\wwwroot\\default.html' -ItemType File -Force -Value ('<html><body><h1>IIS is running on ' + $hostname + '</h1></body></html>')\""
    })
  }

  tags = var.tags
}

# Autoscaling Settings
resource "azurerm_monitor_autoscale_setting" "vmss" {
  count               = var.autoscale_enabled ? 1 : 0
  name                = "${var.prefix}-vmss-autoscale"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.main.id
  enabled             = true

  profile {
    name = "default"

    capacity {
      default = var.autoscale_default_instances
      minimum = var.autoscale_min_instances
      maximum = var.autoscale_max_instances
    }

    # Scale Out Rule - Increase instances when CPU is high
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.main.id
        time_grain         = var.autoscale_metric_time_grain
        statistic          = "Average"
        time_window        = var.autoscale_metric_time_window
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.autoscale_scale_out_cpu_threshold
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = tostring(var.autoscale_scale_out_step)
        cooldown  = var.autoscale_scale_out_cooldown
      }
    }

    # Scale In Rule - Decrease instances when CPU is low
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.main.id
        time_grain         = var.autoscale_metric_time_grain
        statistic          = "Average"
        time_window        = var.autoscale_metric_time_window
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.autoscale_scale_in_cpu_threshold
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = tostring(var.autoscale_scale_in_step)
        cooldown  = var.autoscale_scale_in_cooldown
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      custom_emails                         = var.autoscale_notification_emails
    }
  }

  tags = var.tags
}

# Azure SQL Database Server
resource "azurerm_mssql_server" "main" {
  name                         = "${var.prefix}-sql-server-${substr(md5(azurerm_resource_group.main.location), 0, 8)}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = var.sql_server_version
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"

  tags = var.tags
}

# Azure SQL Database Server Firewall Rule - Allow Azure Services
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Azure SQL Database Server Firewall Rule - Allow VNet Subnet
resource "azurerm_mssql_virtual_network_rule" "allow_subnet" {
  name      = "AllowVNetSubnet"
  server_id = azurerm_mssql_server.main.id
  subnet_id = azurerm_subnet.main.id
}

# Azure SQL Database
resource "azurerm_mssql_database" "main" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = var.sql_database_max_size_gb
  sku_name       = var.sql_database_sku
  zone_redundant = var.sql_database_zone_redundant

  tags = var.tags
}

