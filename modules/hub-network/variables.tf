variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "prefix" { type = string }
variable "address_space" { type = list(string) }
variable "tags" { type = map(string) }

variable "spoke_address_spaces" {
  description = "Spoke ranges allowed out through the firewall"
  type        = list(string)
}

variable "enable_firewall" { type = bool }
variable "enable_bastion" { type = bool }