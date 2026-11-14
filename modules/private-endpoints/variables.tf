variable "resource_group_name" { type = string }
variable "dns_resource_group_name" { type = string }
variable "location" { type = string }
variable "prefix" { type = string }
variable "pe_subnet_id" { type = string }
variable "tags" { type = map(string) }

variable "vnet_ids" {
  description = "VNets to link to the private DNS zones (hub and all spokes)"
  type        = map(string)
}