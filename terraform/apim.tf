# Internal API Management instance for the assessment API layer.
# Developer tier is selected because internal VNet injection is required.
# APIM is deployed in Internal mode — accessible only from within the VNet.
# Private DNS is intentionally deferred to a later change.
# API definitions, backend integration, and mTLS policies will be implemented separately.

resource "azurerm_api_management" "main" {
  name                = local.apim_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name

  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags

  depends_on = [
    azurerm_subnet_network_security_group_association.apim
  ]
}
