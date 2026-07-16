# Provider configuration and shared data sources.
# No Azure resources are created in this file.

provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}

# Reference the pre-existing resource group — this configuration deploys into it
# but does not create or manage the group itself.
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}
