output "firewall_private_ip" {
  value = module.hub.firewall_private_ip
}

output "test_vm_ips" {
  value = { for k, s in module.spoke : k => s.test_vm_private_ip }
}