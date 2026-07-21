# Internal API Management instance for the assessment API layer.
# Developer tier is selected because internal VNet injection is required.
# APIM is deployed in Internal mode with private gateway endpoints in the VNet.
# Private DNS resolves the internal gateway hostname to the APIM private IP within the VNet.

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

resource "azurerm_private_dns_zone" "apim" {
  name                = "azure-api.net"
  resource_group_name = data.azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim" {
  name                  = local.apim_dns_link_name
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.apim.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = local.common_tags
}

resource "azurerm_private_dns_a_record" "apim_gateway" {
  name                = azurerm_api_management.main.name
  zone_name           = azurerm_private_dns_zone.apim.name
  resource_group_name = data.azurerm_resource_group.main.name
  ttl                 = 300
  records             = azurerm_api_management.main.private_ip_addresses

  tags = local.common_tags
}
