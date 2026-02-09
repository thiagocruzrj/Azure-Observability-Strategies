# =============================================================================
# Main Module Configuration - Resource Group and Local Values
# =============================================================================

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # Naming convention: {project}-{resource_type}-{environment}-{location_short}
  location_short = {
    "eastus"        = "eus"
    "eastus2"       = "eus2"
    "westus"        = "wus"
    "westus2"       = "wus2"
    "centralus"     = "cus"
    "northeurope"   = "neu"
    "westeurope"    = "weu"
    "uksouth"       = "uks"
    "ukwest"        = "ukw"
    "southeastasia" = "sea"
    "eastasia"      = "ea"
    "brazilsouth"   = "brs"
  }

  loc_short = lookup(local.location_short, var.location, substr(var.location, 0, 4))

  # Resource naming
  name_prefix = "${var.project_name}-${var.environment}-${local.loc_short}"
  rg_name     = var.resource_group_name != null ? var.resource_group_name : "rg-${local.name_prefix}"

  # Merge all tags
  common_tags = merge(
    {
      Environment     = var.required_tags.Environment
      Project         = var.required_tags.Project
      Owner           = var.required_tags.Owner
      CostCenter      = var.required_tags.CostCenter
      Criticality     = var.required_tags.Criticality
      DataClass       = var.required_tags.DataClass
      ManagedBy       = "Terraform"
      DeploymentDate  = timestamp()
    },
    var.additional_tags
  )

  # Alert thresholds with defaults
  thresholds = {
    cpu_percentage       = coalesce(var.alert_thresholds.cpu_percentage, 80)
    memory_percentage    = coalesce(var.alert_thresholds.memory_percentage, 80)
    http_5xx_count       = coalesce(var.alert_thresholds.http_5xx_count, 10)
    response_time_ms     = coalesce(var.alert_thresholds.response_time_ms, 5000)
    availability_percent = coalesce(var.alert_thresholds.availability_percent, 99.9)
  }

  # Filter apps by type for conditional logic
  web_apps      = { for k, v in var.applications : k => v if v.type == "web" }
  function_apps = { for k, v in var.applications : k => v if v.type == "function" }
  api_apps      = { for k, v in var.applications : k => v if v.type == "api" }

  # Apps with endpoints for availability tests
  apps_with_endpoints = {
    for k, v in var.applications : k => v
    if v.endpoint_url != null && var.enable_availability_tests
  }
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  count    = var.resource_group_name == null ? 1 : 0
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

data "azurerm_resource_group" "existing" {
  count = var.resource_group_name != null ? 1 : 0
  name  = var.resource_group_name
}

locals {
  resource_group_name     = var.resource_group_name != null ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
  resource_group_location = var.resource_group_name != null ? data.azurerm_resource_group.existing[0].location : azurerm_resource_group.main[0].location
  resource_group_id       = var.resource_group_name != null ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.main[0].id
}
