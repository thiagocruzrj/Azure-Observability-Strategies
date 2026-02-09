# =============================================================================
# Variables for Staging Deployment
# =============================================================================

variable "subscription_id" {
  description = "Azure Subscription ID for staging resources"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "contoso"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "owner" {
  description = "Owner of the resources (email)"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

variable "alert_email_recipients" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}
