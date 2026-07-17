# Linux Function App hosting the internal ProcessMessage API on Flex Consumption (FC1).
# Flex Consumption supports regional VNet integration and avoids Elastic Premium VM quota.

resource "azurerm_service_plan" "function" {
  name                = local.app_service_plan_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.resource_group_location
  os_type             = "Linux"
  sku_name            = var.function_app_sku

  tags = local.common_tags
}

# Flex Consumption uses a blob container (not an Azure Files share) for deployment packages.
resource "azurerm_storage_container" "function_deployments" {
  name                  = local.function_storage_container_name
  storage_account_id    = azurerm_storage_account.function.id
  container_access_type = "private"
}

resource "azurerm_function_app_flex_consumption" "main" {
  name                = local.function_app_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.resource_group_location
  service_plan_id     = azurerm_service_plan.function.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.function.primary_blob_endpoint}${azurerm_storage_container.function_deployments.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.function.primary_access_key
  runtime_name                = var.function_worker_runtime
  runtime_version             = var.function_dotnet_version
  maximum_instance_count      = var.function_maximum_instance_count
  instance_memory_in_mb       = var.function_instance_memory_mb

  https_only = true

  # Route outbound traffic through the VNet so the Function can reach private endpoints
  # (Storage, Key Vault, etc.) once those are added in subsequent changes.
  virtual_network_subnet_id = azurerm_subnet.functions.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = true
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~4"
    FUNCTIONS_WORKER_RUNTIME    = var.function_worker_runtime
    WEBSITE_RUN_FROM_PACKAGE    = "1"
  }

  tags = local.common_tags
}
