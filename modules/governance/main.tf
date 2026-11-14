data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

data "azurerm_policy_definition" "require_rg_tag" {
  display_name = "Require a tag on resource groups"
}

data "azurerm_policy_definition" "no_nic_public_ip" {
  display_name = "Network interfaces should not have public IPs"
}

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations (UK only)"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

resource "azurerm_subscription_policy_assignment" "require_rg_tag" {
  name                 = "require-rg-${var.required_tag}-tag"
  display_name         = "Require '${var.required_tag}' tag on resource groups"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.require_rg_tag.id

  parameters = jsonencode({
    tagName = { value = var.required_tag }
  })
}

resource "azurerm_resource_group_policy_assignment" "no_nic_public_ip" {
  for_each             = var.spoke_resource_group_ids
  name                 = "deny-nic-public-ip-${each.key}"
  display_name         = "No public IPs on NICs (${each.key})"
  resource_group_id    = each.value
  policy_definition_id = data.azurerm_policy_definition.no_nic_public_ip.id
}

resource "azurerm_role_definition" "vm_operator" {
  name        = "Lab VM Operator"
  scope       = var.subscription_id
  description = "Can view, start, stop and restart VMs. Cannot create or delete."

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Network/networkInterfaces/read",
    ]
    not_actions = []
  }

  assignable_scopes = [var.subscription_id]
}

resource "azurerm_role_assignment" "vm_operator" {
  count              = var.operator_principal_id == null ? 0 : 1
  scope              = var.subscription_id
  role_definition_id = azurerm_role_definition.vm_operator.role_definition_resource_id
  principal_id       = var.operator_principal_id
}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-log-to-law"
  target_resource_id         = var.subscription_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Security" }
}