location = "uksouth"
prefix   = "lz"

tags = {
  owner       = "prem"
  environment = "lab"
}

spokes = {
  prod = {
    address_space   = ["10.1.0.0/16"]
    workload_subnet = "10.1.1.0/24"
    pe_subnet       = "10.1.2.0/24"
  }
  dev = {
    address_space   = ["10.2.0.0/16"]
    workload_subnet = "10.2.1.0/24"
    pe_subnet       = "10.2.2.0/24"
  }
}