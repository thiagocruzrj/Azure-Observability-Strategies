# =============================================================================
# Input Variables for Azure Observability Module
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 20
    error_message = "Project name must be between 3 and 20 characters."
  }
}

variable "environment" {
  description = "Environment name (prod, stg, dev)"
  type        = string

  validation {
    condition     = contains(["prod", "stg", "dev"], var.environment)
    error_message = "Environment must be one of: prod, stg, dev."
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the existing resource group (optional - creates new if not provided)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Applications Configuration
# -----------------------------------------------------------------------------

variable "applications" {
  description = "Map of applications to deploy with observability"
  type = map(object({
    type            = string           # "web", "function", or "api"
    sku_name        = optional(string, "S1")
    always_on       = optional(bool, true)
    https_only      = optional(bool, true)
    health_check_path = optional(string, "/health")
    runtime_stack   = optional(string, "dotnet")
    runtime_version = optional(string, "v6.0")
    endpoint_url    = optional(string) # For availability tests
  }))

  validation {
    condition = alltrue([
      for app in var.applications : contains(["web", "function", "api"], app.type)
    ])
    error_message = "Application type must be one of: web, function, api."
  }
}

# -----------------------------------------------------------------------------
# App Service Plan Configuration
# -----------------------------------------------------------------------------

variable "app_service_plan_sku" {
  description = "SKU for App Service Plan (F1=Free, B1=Basic, S1=Standard, P1v2=Premium)"
  type        = string
  default     = "F1"

  validation {
    condition     = contains(["F1", "B1", "B2", "B3", "S1", "S2", "S3", "P1v2", "P2v2", "P3v2", "P1v3", "P2v3", "P3v3"], var.app_service_plan_sku)
    error_message = "App Service Plan SKU must be a valid tier: F1, B1-B3, S1-S3, P1v2-P3v2, or P1v3-P3v3."
  }
}

# -----------------------------------------------------------------------------
# Log Analytics Configuration
# -----------------------------------------------------------------------------

variable "log_analytics_sku" {
  description = "SKU for Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics Workspace"
  type        = number
  default     = 90

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Retention days must be between 30 and 730."
  }
}

variable "log_analytics_daily_quota_gb" {
  description = "Daily ingestion quota in GB (-1 for unlimited)"
  type        = number
  default     = 5
}

# -----------------------------------------------------------------------------
# Application Insights Configuration
# -----------------------------------------------------------------------------

variable "app_insights_retention_days" {
  description = "Retention period in days for Application Insights"
  type        = number
  default     = 90
}

variable "app_insights_daily_cap_gb" {
  description = "Daily data cap in GB for Application Insights"
  type        = number
  default     = 1
}

variable "app_insights_sampling_percentage" {
  description = "Sampling percentage for Application Insights (0-100)"
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# Alerting Configuration
# -----------------------------------------------------------------------------

variable "alert_email_recipients" {
  description = "List of email addresses for alert notifications"
  type        = list(string)
  default     = []
}

variable "alert_webhook_url" {
  description = "Webhook URL for alert notifications (optional)"
  type        = string
  default     = null
  sensitive   = true
}

variable "alert_thresholds" {
  description = "Threshold values for alerts"
  type = object({
    cpu_percentage       = optional(number, 80)
    memory_percentage    = optional(number, 80)
    http_5xx_count       = optional(number, 10)
    response_time_ms     = optional(number, 5000)
    availability_percent = optional(number, 99.9)
  })
  default = {}
}

variable "enable_alerts" {
  description = "Enable metric alerts for applications"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Security and Governance
# -----------------------------------------------------------------------------

variable "enable_resource_locks" {
  description = "Enable resource locks (CanNotDelete) - recommended for production"
  type        = bool
  default     = false
}

variable "enable_availability_tests" {
  description = "Enable availability tests (URL ping tests)"
  type        = bool
  default     = false
}

variable "availability_test_frequency" {
  description = "Frequency for availability tests in seconds"
  type        = number
  default     = 300

  validation {
    condition     = contains([300, 600, 900], var.availability_test_frequency)
    error_message = "Frequency must be 300, 600, or 900 seconds."
  }
}

variable "availability_test_locations" {
  description = "List of Azure regions for availability test locations"
  type        = list(string)
  default     = ["us-tx-sn1-azr", "us-il-ch1-azr", "us-ca-sjc-azr", "emea-nl-ams-azr", "apac-jp-kaw-edge"]
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "required_tags" {
  description = "Required tags for all resources"
  type = object({
    Environment  = string
    Project      = string
    Owner        = string
    CostCenter   = string
    Application  = optional(string)
    Criticality  = optional(string, "Medium")
    DataClass    = optional(string, "Internal")
  })
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
