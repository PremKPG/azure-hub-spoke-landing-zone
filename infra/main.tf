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