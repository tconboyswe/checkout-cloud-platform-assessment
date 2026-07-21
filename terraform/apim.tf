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

  hostname_configuration {
    proxy {
      host_name                    = "${local.apim_name}.azure-api.net"
      negotiate_client_certificate = true
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_subnet_network_security_group_association.apim
  ]
}

resource "azurerm_api_management_certificate" "client" {
  name                = local.assessment_certificate_name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = data.azurerm_resource_group.main.name
  key_vault_secret_id = azurerm_key_vault_certificate.assessment.versionless_secret_id

  depends_on = [
    azurerm_role_assignment.apim_key_vault_secrets_user,
  ]
}

resource "azurerm_api_management_api" "process_message" {
  name                  = local.apim_api_name
  resource_group_name   = data.azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Process Message API"
  path                  = "process-message"
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_backend" "function" {
  name                = local.apim_backend_name
  resource_group_name = data.azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_function_app_flex_consumption.main.name}.azurewebsites.net/api"
}

resource "azurerm_api_management_api_operation" "process_message" {
  operation_id        = "process-message"
  api_name            = azurerm_api_management_api.process_message.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = data.azurerm_resource_group.main.name
  display_name        = "Process Message"
  method              = "POST"
  url_template        = "/"

  request {
    description = "JSON payload containing a string message property."

    representation {
      content_type = "application/json"

      example {
        name  = "default"
        value = jsonencode({ message = "hello" })
      }
    }
  }
}

resource "azurerm_api_management_api_policy" "process_message" {
  api_name            = azurerm_api_management_api.process_message.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = data.azurerm_resource_group.main.name

  xml_content = <<POLICY
<policies>
  <inbound>
    <base />
    <validate-client-certificate
      validate-revocation="false"
      validate-trust="false"
      validate-not-before="true"
      validate-not-after="true"
      ignore-error="false">
      <identities>
        <identity thumbprint="${azurerm_api_management_certificate.client.thumbprint}" />
      </identities>
    </validate-client-certificate>
    <set-header name="x-request-id" exists-action="skip">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>
    <set-backend-service backend-id="${azurerm_api_management_backend.function.name}" />
    <rewrite-uri template="/process-message" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
POLICY
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
