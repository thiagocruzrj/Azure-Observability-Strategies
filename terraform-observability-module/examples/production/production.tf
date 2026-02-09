# =============================================================================
# Production Environment - Full Observability Stack
# Web App + Function App with Locks, Alerts, Availability Tests
# =============================================================================

module "production" {
  source = "../../modules/observability"

  project_name = var.project_name
  environment  = "prod"
  location     = var.location

  # Applications to deploy
  applications = {
    "webapp" = {
      type              = "web"
      sku_name          = "S1"
      always_on         = true
      https_only        = true
      health_check_path = "/health"
      runtime_stack     = "dotnet"
      runtime_version   = "v6.0"
      endpoint_url      = "https://app-${var.project_name}-webapp-prod.azurewebsites.net"
    }
    "processor" = {
      type              = "function"
      always_on         = true
      https_only        = true
      health_check_path = "/api/health"
    }
  }

  # Log Analytics Configuration
  log_analytics_retention_days = 90
  log_analytics_daily_quota_gb = 10

  # Application Insights Configuration
  app_insights_retention_days      = 90
  app_insights_daily_cap_gb        = 2
  app_insights_sampling_percentage = 100

  # Alerting Configuration
  enable_alerts          = true
  alert_email_recipients = var.alert_email_recipients
  alert_webhook_url      = var.alert_webhook_url
  alert_thresholds = {
    cpu_percentage       = 80
    memory_percentage    = 80
    http_5xx_count       = 10
    response_time_ms     = 5000
    availability_percent = 99.9
  }

  # Production-specific: Enable locks and availability tests
  enable_resource_locks     = true
  enable_availability_tests = true
  availability_test_frequency = 300
  availability_test_locations = [
    "us-tx-sn1-azr",
    "us-il-ch1-azr",
    "us-ca-sjc-azr",
    "emea-nl-ams-azr",
    "apac-jp-kaw-edge"
  ]

  # Required Tags
  required_tags = {
    Environment = "Production"
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    Criticality = "High"
    DataClass   = "Confidential"
  }

  additional_tags = {
    Team         = "Platform Engineering"
    Compliance   = "SOC2"
    BackupPolicy = "Daily"
  }
}
