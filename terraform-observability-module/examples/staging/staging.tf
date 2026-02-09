# =============================================================================
# Staging Environment - Observability Stack (No Locks, No Availability Tests)
# API App, Web App, Function App
# =============================================================================

module "staging" {
  source = "../../modules/observability"

  project_name = var.project_name
  environment  = "stg"
  location     = var.location

  # Applications to deploy
  applications = {
    "api" = {
      type              = "api"
      sku_name          = "S1"
      always_on         = true
      https_only        = true
      health_check_path = "/api/health"
      runtime_stack     = "dotnet"
      runtime_version   = "v6.0"
      endpoint_url      = null
    }
    "webapp" = {
      type              = "web"
      sku_name          = "S1"
      always_on         = false
      https_only        = true
      health_check_path = "/health"
      runtime_stack     = "dotnet"
      runtime_version   = "v6.0"
    }
    "processor" = {
      type              = "function"
      always_on         = false
      https_only        = true
    }
  }

  # Log Analytics Configuration (shorter retention for staging)
  log_analytics_retention_days = 30
  log_analytics_daily_quota_gb = 2

  # Application Insights Configuration
  app_insights_retention_days      = 30
  app_insights_daily_cap_gb        = 0.5
  app_insights_sampling_percentage = 50

  # Alerting Configuration (less aggressive thresholds)
  enable_alerts          = true
  alert_email_recipients = var.alert_email_recipients
  alert_thresholds = {
    cpu_percentage       = 90
    memory_percentage    = 90
    http_5xx_count       = 50
    response_time_ms     = 10000
    availability_percent = 95
  }

  # Staging-specific: NO locks, NO availability tests
  enable_resource_locks     = false
  enable_availability_tests = false

  # Required Tags
  required_tags = {
    Environment = "Staging"
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    Criticality = "Low"
    DataClass   = "Internal"
  }

  additional_tags = {
    Team         = "Platform Engineering"
    Purpose      = "Pre-production testing"
    AutoShutdown = "true"
  }
}
