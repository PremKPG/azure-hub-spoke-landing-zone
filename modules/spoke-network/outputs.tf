output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "pe_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "test_vm_private_ip" {
  value = try(azurerm_network_interface.test[0].private_ip_address, null)
}