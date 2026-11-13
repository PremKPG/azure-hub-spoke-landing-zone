locals {
  # Our tags plus two that are always added
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

# One resource group per spoke: for_each loops over the spokes map
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