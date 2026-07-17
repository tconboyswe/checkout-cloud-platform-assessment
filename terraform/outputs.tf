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
