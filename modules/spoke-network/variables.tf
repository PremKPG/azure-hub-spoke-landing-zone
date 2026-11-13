variable "name" {
  description = "Spoke name, e.g. prod or dev"
  type        = string
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "prefix" { type = string }
variable "address_space" { type = list(string) }
variable "workload_subnet" { type = string }
variable "pe_subnet" { type = string }
variable "tags" { type = map(string) }

variable "hub_vnet_id" { type = string }
variable "hub_vnet_name" { type = string }
variable "hub_resource_group_name" { type = string }
variable "bastion_subnet_prefix" { type = string }

variable "enable_firewall" { type = bool }
variable "firewall_private_ip" {
  type    = string
  default = null
}

variable "deploy_test_vm" {
  type    = bool
  default = false
}

variable "ssh_public_key" {
  type    = string
  default = ""
}