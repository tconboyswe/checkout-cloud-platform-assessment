# Storage account for the Function App runtime (host storage, triggers, and logs).
# Network restrictions and a private endpoint will be added in a later change.

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  # Storage account names must be globally unique, lowercase alphanumeric, 3-24 characters.
  storage_account_name = substr(
    replace("${var.project_name}${var.environment}${random_string.storage_suffix.result}", "-", ""),
    0,
    24
  )
}

resource "azurerm_storage_account" "function" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = local.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = local.common_tags
}
