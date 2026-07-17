# Core virtual network for the internal API platform.
# Separates compute (Function VNet integration) from private endpoint NICs so
# delegation and network policy requirements do not conflict.

resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = local.common_tags
}

# Dedicated to Azure Function regional VNet integration (Flex Consumption).
# Delegated to Microsoft.App/environments — required for Flex Consumption VNet integration.
resource "azurerm_subnet" "functions" {
  name                 = local.subnet_functions_name
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_functions_address_prefix]

  delegation {
    name = "flex-consumption-delegation"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Dedicated to private endpoints for PaaS services (Storage, Key Vault, APIM, etc.).
# Network policies must be disabled so private endpoint traffic is not blocked by
# route tables or NSGs applied at the subnet level.
resource "azurerm_subnet" "private_endpoints" {
  name                 = local.subnet_private_endpoints_name
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_private_endpoints_address_prefix]

  private_endpoint_network_policies = "Disabled"
}

# Restrict inbound access to the Function integration subnet to HTTPS from within the VNet.
# APIM and other internal callers will reach the Function over this path.
resource "azurerm_network_security_group" "functions" {
  name                = local.nsg_functions_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowInboundHttpsFromVirtualNetwork"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowOutboundHttpsToVirtualNetwork"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = local.common_tags
}

# Allow only the Function subnet to reach private endpoints over HTTPS.
resource "azurerm_network_security_group" "private_endpoints" {
  name                = local.nsg_private_endpoints_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowInboundHttpsFromFunctionsSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.subnet_functions_address_prefix
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "functions" {
  subnet_id                 = azurerm_subnet.functions.id
  network_security_group_id = azurerm_network_security_group.functions.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}
