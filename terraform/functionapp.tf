# Linux Function App hosting the internal ProcessMessage API.
# EP1 (Elastic Premium) is used because regional VNet integration on the existing
# delegated subnet requires a Premium plan — Consumption (Y1) does not support
# VNet integration, and Flex Consumption (FC1) requires Microsoft.App/environments
# subnet delegation instead of Microsoft.Web/serverFarms.

resource "azurerm_service_plan" "function" {
  name                = local.app_service_plan_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.resource_group_location
  os_type             = "Linux"
  sku_name            = var.function_app_sku

  tags = local.common_tags
}

# Linux Function Apps require an Azure Files share for deployment content.
resource "azurerm_storage_share" "function_content" {
  name                 = local.function_content_share_name
  storage_account_name = azurerm_storage_account.function.name
  quota                = 5
}

resource "azurerm_linux_function_app" "main" {
  name                = local.function_app_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.resource_group_location
  service_plan_id     = azurerm_service_plan.function.id

  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

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

    application_stack {
      dotnet_version = var.function_dotnet_version
    }
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~4"
    FUNCTIONS_WORKER_RUNTIME    = var.function_worker_runtime
    WEBSITE_CONTENTSHARE        = azurerm_storage_share.function_content.name
    WEBSITE_RUN_FROM_PACKAGE    = "1"
  }

  tags = local.common_tags
}
