# Input variables for the deployment.
# Values are supplied via terraform.tfvars (local) or TF_VAR_* environment variables (CI).

variable "subscription_id" {
  description = "Azure subscription ID where resources will be deployed."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid Azure subscription GUID."
  }
}

variable "resource_group_name" {
  description = "Name of the existing resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region for resources. Should match the existing resource group."
  type        = string
}

variable "environment" {
  description = "Environment name used in naming and tagging (e.g. dev, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "project_name" {
  description = "Short project name used as the base for resource naming."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vnet_address_space" {
  description = "Address space CIDR blocks for the virtual network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_functions_address_prefix" {
  description = "CIDR for the Function App VNet integration subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "subnet_private_endpoints_address_prefix" {
  description = "CIDR for the private endpoints subnet."
  type        = string
  default     = "10.10.2.0/24"
}

variable "function_app_sku" {
  description = "App Service plan SKU for the Function App. FC1 is the Flex Consumption plan."
  type        = string
  default     = "FC1"
}

variable "function_worker_runtime" {
  description = "Functions worker runtime identifier."
  type        = string
  default     = "dotnet-isolated"
}

variable "function_dotnet_version" {
  description = ".NET version for the Function App runtime."
  type        = string
  default     = "8.0"
}

variable "function_maximum_instance_count" {
  description = "Maximum instance count for Flex Consumption scale-out."
  type        = number
  default     = 40
}

variable "function_instance_memory_mb" {
  description = "Instance memory size in MB for Flex Consumption."
  type        = number
  default     = 2048
}

variable "certificate_common_name" {
  description = "Common name (CN) for the self-signed assessment certificate."
  type        = string
  default     = "checkout-assessment-dev.internal"
}

variable "certificate_organization" {
  description = "Organization (O) for the self-signed assessment certificate subject."
  type        = string
  default     = "Checkout Assessment"
}

variable "key_vault_public_network_access_enabled" {
  description = "Whether Key Vault accepts public network traffic. Set to false after local certificate deployment is complete."
  type        = bool
  default     = true
}

variable "key_vault_allowed_ip_rules" {
  description = "Public IP CIDR ranges allowed to reach the Key Vault data plane (e.g. [\"203.0.113.10/32\"] for a single workstation)."
  type        = list(string)
  default     = []
}
