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
