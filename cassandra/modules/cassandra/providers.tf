terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3"
    }
  }
}
