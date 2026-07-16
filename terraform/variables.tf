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
