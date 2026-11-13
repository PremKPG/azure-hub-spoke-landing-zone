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