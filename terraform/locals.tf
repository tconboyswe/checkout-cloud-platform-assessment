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
  subnet_functions_name         = "${local.name_prefix}-snet-functions"
  subnet_private_endpoints_name = "${local.name_prefix}-snet-private-endpoints"

  # Reserved for upcoming resources — keeps naming consistent across the module
  function_app_name     = "${local.name_prefix}-func"
  app_service_plan_name = "${local.name_prefix}-asp"
  key_vault_name        = "${local.name_prefix}-kv"
  app_insights_name     = "${local.name_prefix}-appi"
  log_analytics_name    = "${local.name_prefix}-log"
  apim_name             = "${local.name_prefix}-apim"

  # Azure Files share for Linux Function App deployment content (3-63 chars, lowercase)
  function_content_share_name = lower(local.function_app_name)

  # Location taken from the existing resource group to avoid region mismatches
  resource_group_location = data.azurerm_resource_group.main.location

  # Tags applied to all resources created by this configuration
  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
