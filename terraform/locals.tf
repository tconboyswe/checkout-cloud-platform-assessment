# Derived values used across the configuration.
# Centralising naming and tags here keeps resource definitions consistent.

locals {
  # Prefix applied to hyphenated Azure resource names, e.g. checkout-assessment-dev
  name_prefix = "${var.project_name}-${var.environment}"

  # Compact form for resources that disallow hyphens (e.g. Storage Account)
  name_prefix_compact = replace(local.name_prefix, "-", "")

  # --- Hyphenated Azure resource names (checkout-assessment-dev-<type>) ---

  vnet_name                     = "${local.name_prefix}-vnet"
  nsg_functions_name            = "${local.name_prefix}-nsg-functions"
  nsg_private_endpoints_name    = "${local.name_prefix}-nsg-private-endpoints"
  nsg_apim_name                 = "${local.name_prefix}-nsg-apim"
  subnet_functions_name         = "${local.name_prefix}-snet-functions"
  subnet_private_endpoints_name = "${local.name_prefix}-snet-private-endpoints"
  subnet_apim_name              = "${local.name_prefix}-snet-apim"

  # Reserved for upcoming resources — keeps naming consistent across the module
  function_app_name     = "${local.name_prefix}-func"
  app_service_plan_name = "${local.name_prefix}-asp"
  # Key Vault names are globally unique and limited to 24 characters.
  key_vault_name                  = substr("${local.name_prefix_compact}kv", 0, 24)
  key_vault_private_endpoint_name = "${local.name_prefix}-kv-pe"
  key_vault_dns_link_name         = "${local.name_prefix}-kv-dns-link"
  assessment_certificate_name     = "${local.name_prefix}-cert"
  app_insights_name               = "${local.name_prefix}-appi"
  log_analytics_name              = "${local.name_prefix}-log"
  apim_name                       = "${local.name_prefix}-apim"
  apim_dns_link_name              = "${local.name_prefix}-apim-dns-link"

  # Blob container for Flex Consumption deployment packages
  function_storage_container_name = "${local.name_prefix}-deployments"

  # Location taken from the existing resource group to avoid region mismatches
  resource_group_location = data.azurerm_resource_group.main.location

  # Tags applied to all resources created by this configuration
  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
