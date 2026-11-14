variable "location" {
  type    = string
  default = "uksouth"
}

variable "prefix" {
  type    = string
  default = "lz"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "spokes" {
  description = "Spoke VNets to create, keyed by environment name"
  type = map(object({
    address_space   = list(string)
    workload_subnet = string
    pe_subnet       = string
  }))
}

variable "hub_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "enable_firewall" {
  description = "Deploy Azure Firewall (main cost driver)"
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion"
  type        = bool
  default     = false
}

variable "deploy_test_vms" {
  type    = bool
  default = false
}

variable "ssh_public_key" {
  description = "Supplied via TF_VAR_ssh_public_key, never committed"
  type        = string
  default     = ""
}

variable "test_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}