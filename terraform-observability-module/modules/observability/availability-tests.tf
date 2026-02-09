# =============================================================================
# Availability Tests (URL Ping Tests) - Production Only
# =============================================================================

# -----------------------------------------------------------------------------
# Standard URL Ping Tests
# -----------------------------------------------------------------------------

resource "azurerm_application_insights_standard_web_test" "availability" {
  for_each = local.apps_with_endpoints

  name                    = "avt-${var.project_name}-${each.key}-${var.environment}"
  location                = local.resource_group_location
  resource_group_name     = local.resource_group_name
  application_insights_id = azurerm_application_insights.apps[each.key].id

  geo_locations = var.availability_test_locations
  frequency     = var.availability_test_frequency
  timeout       = 30
  enabled       = true

  request {
    url                              = each.value.endpoint_url
    http_verb                        = "GET"
    parse_dependent_requests_enabled = true
    follow_redirects_enabled         = true
  }

  validation_rules {
    expected_status_code        = 200
    ssl_check_enabled           = true
    ssl_cert_remaining_lifetime = 30
  }

  tags = merge(local.common_tags, {
    ResourceType = "Availability Test"
    Application  = each.key
    TestType     = "URL Ping"
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Health Check Endpoint Tests (using health_check_path from app config)
# -----------------------------------------------------------------------------

locals {
  # Apps with health endpoints for health-specific tests
  web_apps_health = {
    for k, v in local.web_apps : k => v
    if v.health_check_path != null && var.enable_availability_tests
  }
  
  api_apps_health = {
    for k, v in local.api_apps : k => v
    if v.health_check_path != null && var.enable_availability_tests
  }
}

resource "azurerm_application_insights_standard_web_test" "health_web" {
  for_each = local.web_apps_health

  name                    = "avt-health-${each.key}-${var.environment}"
  location                = local.resource_group_location
  resource_group_name     = local.resource_group_name
  application_insights_id = azurerm_application_insights.apps[each.key].id

  geo_locations = var.availability_test_locations
  frequency     = var.availability_test_frequency
  timeout       = 30
  enabled       = true

  request {
    url                              = "https://${azurerm_windows_web_app.web[each.key].default_hostname}${each.value.health_check_path}"
    http_verb                        = "GET"
    parse_dependent_requests_enabled = false
    follow_redirects_enabled         = true
  }

  validation_rules {
    expected_status_code = 200
  }

  tags = merge(local.common_tags, {
    ResourceType = "Availability Test"
    Application  = each.key
    TestType     = "Health Check"
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_application_insights_standard_web_test" "health_api" {
  for_each = local.api_apps_health

  name                    = "avt-health-${each.key}-${var.environment}"
  location                = local.resource_group_location
  resource_group_name     = local.resource_group_name
  application_insights_id = azurerm_application_insights.apps[each.key].id

  geo_locations = var.availability_test_locations
  frequency     = var.availability_test_frequency
  timeout       = 30
  enabled       = true

  request {
    url                              = "https://${azurerm_windows_web_app.api[each.key].default_hostname}${each.value.health_check_path}"
    http_verb                        = "GET"
    parse_dependent_requests_enabled = false
    follow_redirects_enabled         = true
  }

  validation_rules {
    expected_status_code = 200
  }

  tags = merge(local.common_tags, {
    ResourceType = "Availability Test"
    Application  = each.key
    TestType     = "Health Check"
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}
