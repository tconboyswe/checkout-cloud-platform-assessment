# Azure Key Vault for secrets and certificates used by the internal API platform.

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled      = true
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  soft_delete_retention_days      = 7
  purge_protection_enabled        = true
  public_network_access_enabled   = var.key_vault_public_network_access_enabled

  # Deny all public data-plane access by default; permit only explicitly listed IPs.
  network_acls {
    default_action = "Deny"
    bypass         = "None"
    ip_rules       = var.key_vault_allowed_ip_rules
  }

  tags = local.common_tags
}

# Allows Terraform to import certificates during apply when the caller's public IP
# is included in key_vault_allowed_ip_rules.
resource "azurerm_role_assignment" "key_vault_terraform_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = local.key_vault_dns_link_name
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = local.key_vault_private_endpoint_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${local.name_prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }

  tags = local.common_tags
}

# Minimum RBAC for the Function App to read secrets and certificates at runtime.
resource "azurerm_role_assignment" "function_key_vault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_key_vault_certificates_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "apim_key_vault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.main.identity[0].principal_id
}
