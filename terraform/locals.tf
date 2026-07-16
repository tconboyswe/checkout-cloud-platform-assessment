# Derived values used across the configuration.
# Centralising naming and tags here keeps resource definitions consistent.

locals {
  # Prefix applied to resource names, e.g. checkout-assessment-dev
  name_prefix = "${var.project_name}-${var.environment}"

  # Location taken from the existing resource group to avoid region mismatches
  resource_group_location = data.azurerm_resource_group.main.location

  # Tags applied to all resources created by this configuration
  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
