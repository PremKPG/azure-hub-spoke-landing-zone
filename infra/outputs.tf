output "firewall_private_ip" {
  value = module.hub.firewall_private_ip
}

output "test_vm_ips" {
  value = { for k, s in module.spoke : k => s.test_vm_private_ip }
}

output "key_vault_name" {
  value = try(module.private_endpoints[0].key_vault_name, null)
}

output "storage_account_name" {
  value = try(module.private_endpoints[0].storage_account_name, null)
}