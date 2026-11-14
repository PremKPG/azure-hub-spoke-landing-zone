resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.prefix}-hub-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space[0], 10, 0)] # 10.0.0.0/26
}

resource "azurerm_subnet" "firewall_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space[0], 10, 1)] # 10.0.0.64/26
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space[0], 10, 4)] # 10.0.1.0/26
}


resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.prefix}-hub-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_public_ip" "fw" {
  count               = var.enable_firewall ? 1 : 0
  name                = "pip-${var.prefix}-fw-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "fw_mgmt" {
  count               = var.enable_firewall ? 1 : 0
  name                = "pip-${var.prefix}-fw-mgmt-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afwp-${var.prefix}-hub-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  tags                = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  count              = var.enable_firewall ? 1 : 0
  name               = "rcg-baseline"
  firewall_policy_id = azurerm_firewall_policy.this[0].id
  priority           = 200

  application_rule_collection {
    name     = "allow-outbound-web"
    priority = 200
    action   = "Allow"

    rule {
      name              = "os-updates-and-egress-test"
      source_addresses  = var.spoke_address_spaces
      destination_fqdns = ["*.ubuntu.com", "ifconfig.me"]

      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afw-${var.prefix}-hub-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw[0].id
  }

  management_ip_configuration {
    name                 = "mgmt-ipconfig"
    subnet_id            = azurerm_subnet.firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.fw_mgmt[0].id
  }
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count                          = var.enable_firewall ? 1 : 0
  name                           = "diag-to-law"
  target_resource_id             = azurerm_firewall.this[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-${var.prefix}-bas-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-${var.prefix}-hub-uks"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}