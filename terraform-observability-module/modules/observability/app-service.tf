# =============================================================================
# App Service Plans and App Services (Web, Function, API)
# =============================================================================

# -----------------------------------------------------------------------------
# App Service Plan (shared across apps in same tier)
# -----------------------------------------------------------------------------

resource "azurerm_service_plan" "main" {
  name                = "asp-${local.name_prefix}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  os_type             = "Windows"
  sku_name            = var.app_service_plan_sku

  tags = merge(local.common_tags, {
    ResourceType = "App Service Plan"
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Web Apps
# -----------------------------------------------------------------------------

resource "azurerm_windows_web_app" "web" {
  for_each = local.web_apps

  name                = "app-${var.project_name}-${each.key}-${var.environment}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id

  https_only = each.value.https_only
  
  site_config {
    # always_on is not supported on Free (F1) tier
    always_on                = var.app_service_plan_sku == "F1" ? false : each.value.always_on
    http2_enabled            = true
    minimum_tls_version      = "1.2"
    ftps_state               = "Disabled"
    health_check_path        = each.value.health_check_path
    health_check_eviction_time_in_min = 5

    application_stack {
      current_stack  = each.value.runtime_stack
      dotnet_version = each.value.runtime_version
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.apps[each.key].connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "XDT_MicrosoftApplicationInsights_Mode" = "Recommended"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.common_tags, {
    ResourceType = "Web App"
    Application  = each.key
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Function Apps
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "function" {
  for_each = local.function_apps

  name                     = lower(replace("st${var.project_name}${each.key}${var.environment}", "-", ""))
  resource_group_name      = local.resource_group_name
  location                 = local.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
  shared_access_key_enabled       = false

  tags = merge(local.common_tags, {
    ResourceType = "Storage Account"
    Purpose      = "Function App Storage"
    Application  = each.key
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_windows_function_app" "function" {
  for_each = local.function_apps

  name                          = "func-${var.project_name}-${each.key}-${var.environment}"
  location                      = local.resource_group_location
  resource_group_name           = local.resource_group_name
  service_plan_id               = azurerm_service_plan.main.id
  storage_account_name          = azurerm_storage_account.function[each.key].name
  storage_uses_managed_identity = true

  https_only = each.value.https_only

  site_config {
    # always_on is not supported on Free (F1) tier
    always_on                = var.app_service_plan_sku == "F1" ? false : each.value.always_on
    http2_enabled            = true
    minimum_tls_version      = "1.2"
    ftps_state               = "Disabled"

    application_insights_connection_string = azurerm_application_insights.apps[each.key].connection_string
    application_insights_key               = azurerm_application_insights.apps[each.key].instrumentation_key

    application_stack {
      dotnet_version              = "v8.0"
      use_dotnet_isolated_runtime = true
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.common_tags, {
    ResourceType = "Function App"
    Application  = each.key
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# API Apps (Windows Web Apps configured as API)
# -----------------------------------------------------------------------------

resource "azurerm_windows_web_app" "api" {
  for_each = local.api_apps

  name                = "api-${var.project_name}-${each.key}-${var.environment}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id

  https_only = each.value.https_only
  
  site_config {
    # always_on is not supported on Free (F1) tier
    always_on                = var.app_service_plan_sku == "F1" ? false : each.value.always_on
    http2_enabled            = true
    minimum_tls_version      = "1.2"
    ftps_state               = "Disabled"
    health_check_path        = each.value.health_check_path
    health_check_eviction_time_in_min = 5
    cors {
      allowed_origins     = ["*"]
      support_credentials = false
    }

    application_stack {
      current_stack  = each.value.runtime_stack
      dotnet_version = each.value.runtime_version
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.apps[each.key].connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "XDT_MicrosoftApplicationInsights_Mode" = "Recommended"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.common_tags, {
    ResourceType = "API App"
    Application  = each.key
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings for App Services
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "web_apps" {
  for_each = local.web_apps

  name                       = "diag-${each.key}"
  target_resource_id         = azurerm_windows_web_app.web[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
  # Check the importance of each log category for your monitoring needs and costs
  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_log {
    category = "AppServiceAuditLogs"
  }

  enabled_log {
    category = "AppServicePlatformLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "function_apps" {
  for_each = local.function_apps

  name                       = "diag-${each.key}"
  target_resource_id         = azurerm_windows_function_app.function[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "FunctionAppLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "api_apps" {
  for_each = local.api_apps

  name                       = "diag-${each.key}"
  target_resource_id         = azurerm_windows_web_app.api[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
  
  # Check the importance of each log category for your monitoring needs and costs
  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_log {
    category = "AppServiceAuditLogs"
  }

  enabled_log {
    category = "AppServicePlatformLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# -----------------------------------------------------------------------------
# Role Assignments for Function Apps to Access Storage (Managed Identity)
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "function_storage_blob" {
  for_each = local.function_apps

  scope                = azurerm_storage_account.function[each.key].id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_windows_function_app.function[each.key].identity[0].principal_id
}

resource "azurerm_role_assignment" "function_storage_queue" {
  for_each = local.function_apps

  scope                = azurerm_storage_account.function[each.key].id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.function[each.key].identity[0].principal_id
}

resource "azurerm_role_assignment" "function_storage_table" {
  for_each = local.function_apps

  scope                = azurerm_storage_account.function[each.key].id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_windows_function_app.function[each.key].identity[0].principal_id
}
