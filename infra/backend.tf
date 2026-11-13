terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-uks"
    storage_account_name = "sttfstate429ad97e"
    container_name       = "tfstate"
    key                  = "landing-zone.tfstate" 
    use_azuread_auth     = true                     
  }
}