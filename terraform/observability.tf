# Observability platform: Log Analytics, Application Insights, and operational alerting.

locals {
  function_memory_alert_name = "${local.name_prefix}-func-memory"
  monitor_action_group_name  = "${local.name_prefix}-ag"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_in_days

  tags = local.common_tags
}

resource "azurerm_application_insights" "main" {
  name                = local.app_insights_name
  location            = local.resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "main" {
  count = length(var.alert_email_receivers) > 0 ? 1 : 0

  name                = local.monitor_action_group_name
  resource_group_name = data.azurerm_resource_group.main.name
  short_name          = substr(replace(local.name_prefix, "-", ""), 0, 12)

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = local.common_tags
}

# AverageMemoryWorkingSet is exposed by Flex Consumption (Microsoft.Web/sites); Http5xx is not.
moved {
  from = azurerm_monitor_metric_alert.function_http5xx
  to   = azurerm_monitor_metric_alert.function_memory
}

resource "azurerm_monitor_metric_alert" "function_memory" {
  name                = local.function_memory_alert_name
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [azurerm_function_app_flex_consumption.main.id]
  description         = "Function App average memory working set exceeded the configured threshold."
  severity            = var.alert_severity
  frequency           = var.alert_evaluation_frequency
  window_size         = var.alert_window_size
  enabled             = true
  auto_mitigate       = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "AverageMemoryWorkingSet"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alert_threshold
  }

  dynamic "action" {
    for_each = length(var.alert_email_receivers) > 0 ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.main[0].id
    }
  }

  tags = local.common_tags
}
