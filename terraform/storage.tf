# Storage account for the Function App runtime (host storage, triggers, and logs).
# Network restrictions and a private endpoint will be added in a later change.

resource "random_string" "storage_suffix" {
  length  = 3
  special = false
  upper   = false
}

resource "azurerm_storage_account" "function" {
  # Storage account names: no hyphens, max 24 chars — <compact-prefix>sa<suffix>
  name = substr(
    "${local.name_prefix_compact}sa${random_string.storage_suffix.result}",
    0,
    24
  )
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = local.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = local.common_tags
}
