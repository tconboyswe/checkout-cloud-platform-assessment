output "virtual_network_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.main.id
}

output "subnet_functions_id" {
  description = "Resource ID of the Function App VNet integration subnet."
  value       = azurerm_subnet.functions.id
}

output "subnet_private_endpoints_id" {
  description = "Resource ID of the private endpoints subnet."
  value       = azurerm_subnet.private_endpoints.id
}

output "storage_account_name" {
  description = "Name of the Function App storage account."
  value       = azurerm_storage_account.function.name
}

output "storage_account_id" {
  description = "Resource ID of the Function App storage account."
  value       = azurerm_storage_account.function.id
}

output "function_app_name" {
  description = "Name of the Function App."
  value       = azurerm_function_app_flex_consumption.main.name
}

output "function_app_principal_id" {
  description = "Principal ID of the Function App system-assigned managed identity."
  value       = azurerm_function_app_flex_consumption.main.identity[0].principal_id
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_private_endpoint_ip" {
  description = "Private IP address of the Key Vault private endpoint."
  value       = azurerm_private_endpoint.keyvault.private_service_connection[0].private_ip_address
}

output "key_vault_certificate_name" {
  description = "Name of the self-signed certificate stored in Key Vault."
  value       = azurerm_key_vault_certificate.assessment.name
}
