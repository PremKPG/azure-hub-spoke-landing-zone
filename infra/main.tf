locals {
  tags = merge(var.tags, {
    project    = "hub-spoke-landing-zone"
    managed_by = "terraform"
  })
}

resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.prefix}-hub-uks"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "spoke" {
  for_each = var.spokes

  name     = "rg-${var.prefix}-spoke-${each.key}-uks"
  location = var.location
  tags     = local.tags
}

module "hub" {
  source = "../modules/hub-network"

  resource_group_name  = azurerm_resource_group.hub.name
  location             = var.location
  prefix               = var.prefix
  address_space        = var.hub_address_space
  spoke_address_spaces = flatten([for s in var.spokes : s.address_space])
  enable_firewall      = var.enable_firewall
  enable_bastion       = var.enable_bastion
  tags                 = local.tags
}

module "spoke" {
  source   = "../modules/spoke-network"
  for_each = var.spokes

  name                    = each.key
  resource_group_name     = azurerm_resource_group.spoke[each.key].name
  location                = var.location
  prefix                  = var.prefix
  address_space           = each.value.address_space
  workload_subnet         = each.value.workload_subnet
  pe_subnet               = each.value.pe_subnet
  hub_vnet_id             = module.hub.vnet_id
  hub_vnet_name           = module.hub.vnet_name
  hub_resource_group_name = azurerm_resource_group.hub.name
  bastion_subnet_prefix   = cidrsubnet(var.hub_address_space[0], 10, 4)
  enable_firewall         = var.enable_firewall
  firewall_private_ip     = module.hub.firewall_private_ip
  deploy_test_vm          = var.deploy_test_vms
  ssh_public_key          = var.ssh_public_key
  tags                    = local.tags
  vm_size                 = var.test_vm_size
}

module "private_endpoints" {
  source = "../modules/private-endpoints"
  count  = var.enable_private_endpoints ? 1 : 0

  resource_group_name     = azurerm_resource_group.spoke["prod"].name
  dns_resource_group_name = azurerm_resource_group.hub.name
  location                = var.location
  prefix                  = var.prefix
  pe_subnet_id            = module.spoke["prod"].pe_subnet_id
  tags                    = local.tags

  vnet_ids = merge(
    { hub = module.hub.vnet_id },
    { for k, s in module.spoke : k => s.vnet_id }
  )
}

data "azurerm_subscription" "current" {}

module "governance" {
  source = "../modules/governance"

  subscription_id            = data.azurerm_subscription.current.id
  spoke_resource_group_ids   = { for k, rg in azurerm_resource_group.spoke : k => rg.id }
  allowed_locations          = ["uksouth", "ukwest"]
  required_tag               = "owner"
  log_analytics_workspace_id = module.hub.log_analytics_workspace_id
}