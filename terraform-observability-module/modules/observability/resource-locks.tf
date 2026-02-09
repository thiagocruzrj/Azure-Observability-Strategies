# =============================================================================
# Resource Locks - Production Only (CanNotDelete)
# =============================================================================

# Resource locks prevent accidental deletion of critical resources.
# Only enable for production environments.

# -----------------------------------------------------------------------------
# Log Analytics Workspace Lock
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "law" {
  count = var.enable_resource_locks ? 1 : 0

  name       = "lock-law-${local.name_prefix}"
  scope      = azurerm_log_analytics_workspace.main.id
  lock_level = "CanNotDelete"
  notes      = "Production Log Analytics Workspace - Protected from accidental deletion"
}

# -----------------------------------------------------------------------------
# Application Insights Locks
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "app_insights" {
  for_each = var.enable_resource_locks ? var.applications : {}

  name       = "lock-ai-${each.key}"
  scope      = azurerm_application_insights.apps[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Production Application Insights for ${each.key} - Protected from accidental deletion"
}

# -----------------------------------------------------------------------------
# Web App Locks
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "web_apps" {
  for_each = var.enable_resource_locks ? local.web_apps : {}

  name       = "lock-app-${each.key}"
  scope      = azurerm_windows_web_app.web[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Production Web App ${each.key} - Protected from accidental deletion"
}

# -----------------------------------------------------------------------------
# Function App Locks
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "function_apps" {
  for_each = var.enable_resource_locks ? local.function_apps : {}

  name       = "lock-func-${each.key}"
  scope      = azurerm_windows_function_app.function[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Production Function App ${each.key} - Protected from accidental deletion"
}

resource "azurerm_management_lock" "function_storage" {
  for_each = var.enable_resource_locks ? local.function_apps : {}

  name       = "lock-st-${each.key}"
  scope      = azurerm_storage_account.function[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Production Storage Account for ${each.key} - Protected from accidental deletion"
}

# -----------------------------------------------------------------------------
# API App Locks
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "api_apps" {
  for_each = var.enable_resource_locks ? local.api_apps : {}

  name       = "lock-api-${each.key}"
  scope      = azurerm_windows_web_app.api[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Production API App ${each.key} - Protected from accidental deletion"
}

# -----------------------------------------------------------------------------
# App Service Plan Lock
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "app_service_plan" {
  count = var.enable_resource_locks ? 1 : 0

  name       = "lock-asp-${local.name_prefix}"
  scope      = azurerm_service_plan.main.id
  lock_level = "CanNotDelete"
  notes      = "Production App Service Plan - Protected from accidental deletion"
}

# -----------------------------------------------------------------------------
# Resource Group Lock (optional - locks entire RG)
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "resource_group" {
  count = var.enable_resource_locks && var.resource_group_name == null ? 1 : 0

  name       = "lock-rg-${local.name_prefix}"
  scope      = azurerm_resource_group.main[0].id
  lock_level = "CanNotDelete"
  notes      = "Production Resource Group - Protected from accidental deletion"
}
