output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Next hop for spoke routes. null when the firewall is off."
  value       = try(azurerm_firewall.this[0].ip_configuration[0].private_ip_address, null)
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}