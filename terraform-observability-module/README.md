# Azure Observability Terraform Module

> **Purpose**: Reusable Terraform module demonstrating Azure observability best practices  
> **Scope**: Web Apps, Function Apps, API Apps with full monitoring stack  
> **Version**: 1.0.0

---

## 📋 What This Module Creates

| Resource | Production | Staging | Per Resource |
|----------|------------|---------|--------------|
| App Service (Web/Function/API) | ✅ | ✅ | - |
| Application Insights | ✅ | ✅ | 1 per app |
| Log Analytics Workspace | ✅ | ✅ | 1 per location |
| Action Groups | ✅ | ✅ | 1 per environment |
| Metric Alerts | ✅ | ✅ | Multiple per app |
| Availability Tests | ✅ | ❌ | 1 per web app |
| Resource Locks | ✅ | ❌ | All critical resources |
| Diagnostic Settings | ✅ | ✅ | All resources |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Production Subscription                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-observability-prod-northeurope          │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │   Web App    │  │ Function App │  │  API App     │       │   │
│  │  │   (locked)   │  │   (locked)   │  │  (locked)    │       │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │   │
│  │         │                 │                 │                │   │
│  │         ▼                 ▼                 ▼                │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │ App Insights │  │ App Insights │  │ App Insights │       │   │
│  │  │  (locked)    │  │  (locked)    │  │  (locked)    │       │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │   │
│  │         │                 │                 │                │   │
│  │         └─────────────────┼─────────────────┘                │   │
│  │                           ▼                                  │   │
│  │                 ┌──────────────────┐                         │   │
│  │                 │ Log Analytics WS │                         │   │
│  │                 │    (locked)      │                         │   │
│  │                 └────────┬─────────┘                         │   │
│  │                          │                                   │   │
│  │              ┌───────────┴───────────┐                       │   │
│  │              ▼                       ▼                       │   │
│  │    ┌─────────────────┐     ┌─────────────────┐              │   │
│  │    │  Action Group   │     │ Availability    │              │   │
│  │    │  (Email + SMS)  │     │ Tests           │              │   │
│  │    └─────────────────┘     └─────────────────┘              │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     Staging Subscription                            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-observability-stg-northeurope           │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │   Web App    │  │ Function App │  │  API App     │       │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │   │
│  │         │                 │                 │                │   │
│  │         ▼                 ▼                 ▼                │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │ App Insights │  │ App Insights │  │ App Insights │       │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │   │
│  │         │                 │                 │                │   │
│  │         └─────────────────┼─────────────────┘                │   │
│  │                           ▼                                  │   │
│  │                 ┌──────────────────┐                         │   │
│  │                 │ Log Analytics WS │                         │   │
│  │                 └──────────────────┘                         │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## � Lifecycle - Testing & Deployment

### Prerequisites

```bash
# 1. Install Terraform (>= 1.5.0)
# Windows (winget)
winget install Hashicorp.Terraform

# Verify installation
terraform --version

# 2. Install Azure CLI
winget install Microsoft.AzureCLI

# 3. Login to Azure
az login

# 4. Set your subscription (optional)
az account set --subscription "your-subscription-id"
az account show
```

### Step 1: Initialize

```bash
# Navigate to example directory
cd terraform-observability-module/examples/simple

# Initialize Terraform (downloads providers)
terraform init
```

### Step 2: Validate

```bash
# Validate configuration syntax
terraform validate

# Format code (optional)
terraform fmt -recursive
```

### Step 3: Plan

```bash
# Preview what will be created
terraform plan -out=tfplan

# Or with variables file
terraform plan -var-file="terraform.tfvars" -out=tfplan
```

### Step 4: Apply

```bash
# Apply the plan (creates resources)
terraform apply tfplan

# Or apply directly with auto-approve (use with caution)
terraform apply -auto-approve
```

### Step 5: Verify

```bash
# Show outputs
terraform output

# Show specific output
terraform output -json web_apps

# Verify in Azure
az resource list --resource-group "rg-quickstart-dev-eus" --output table
```

### Step 6: Destroy (Cleanup)

```bash
# Preview destruction
terraform plan -destroy

# Destroy all resources
terraform destroy

# Or with auto-approve
terraform destroy -auto-approve
```

---

## 🧪 Testing Commands

### Quick Test (Simple Example)

```bash
# From repository root
cd terraform-observability-module/examples/simple

# Edit main.tf to set your email
# Then run:
terraform init
terraform plan
terraform apply -auto-approve

# Verify resources created
az webapp list --query "[].{name:name, state:state}" -o table
az monitor app-insights component list --query "[].{name:name, appId:appId}" -o table

# Cleanup
terraform destroy -auto-approve
```

### Full Test (Multi-Subscription)

```bash
cd terraform-observability-module/examples/complete

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription IDs

terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Cleanup
terraform destroy -var-file="terraform.tfvars"
```

---

## 🚀 Quick Start

### 1. Configure Providers

```hcl
# main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }
}

# Single subscription provider
provider "azurerm" {
  features {}
}

# For multi-subscription, add aliased providers:
# provider "azurerm" {
#   alias           = "prod"
#   subscription_id = "your-prod-subscription-id"
#   features {}
# }
#
# provider "azurerm" {
#   alias           = "stg"
#   subscription_id = "your-stg-subscription-id"
#   features {}
# }
```

### 2. Use the Module

```hcl
module "observability_prod" {
  source = "./modules/observability"
  
  providers = {
    azurerm = azurerm.prod
  }

  environment         = "prod"
  location            = "northeurope"
  project_name        = "myapp"
  
  # App configurations
  apps = {
    web = {
      type     = "web"
      sku_name = "P1v3"
    }
    func = {
      type     = "function"
      sku_name = "Y1"
    }
    api = {
      type     = "api"
      sku_name = "P1v3"
    }
  }

  # Monitoring settings
  log_retention_days     = 90
  daily_cap_gb           = 10
  enable_resource_locks  = true
  enable_availability_tests = true

  # Alert recipients
  alert_email_addresses = ["ops-team@company.com"]
  alert_sms_recipients  = [
    {
      name         = "OnCall"
      country_code = "1"
      phone_number = "5551234567"
    }
  ]

  tags = {
    Owner       = "Platform Team"
    CostCenter  = "IT-001"
    Application = "MyApp"
  }
}
```

---

## 📁 Module Structure

```
terraform-observability-module/
├── README.md
├── examples/
│   └── complete/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── modules/
    └── observability/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── app-service.tf
        ├── app-insights.tf
        ├── log-analytics.tf
        ├── alerts.tf
        ├── availability-tests.tf
        ├── resource-locks.tf
        └── versions.tf
```

---

## 📖 Usage Examples

See the [examples/complete](./examples/complete/) directory for a full working example.

---

## 🔒 Security & Governance

This module implements:

- ✅ Resource locks on production resources
- ✅ Workspace-based Application Insights
- ✅ IP masking enabled by default
- ✅ Daily caps for cost control
- ✅ Proper retention settings
- ✅ Diagnostic settings for all resources
- ✅ Consistent tagging strategy

---

## 📊 Alerts Included

| Alert | Metric | Threshold | Severity |
|-------|--------|-----------|----------|
| High CPU | CpuPercentage | > 80% | Warning |
| High Memory | MemoryPercentage | > 80% | Warning |
| 5xx Errors | Http5xx | > 10 | Error |
| Response Time | AverageResponseTime | > 5s | Warning |
| Availability Down | availabilityResults/availabilityPercentage | < 95% | Critical |

---

## 🏷️ Required Tags

| Tag | Description | Example |
|-----|-------------|---------|
| Environment | Deployment environment | prod, stg, dev |
| Owner | Team or person responsible | Platform Team |
| CostCenter | Billing allocation | IT-001 |
| Application | Application name | MyApp |
| ManagedBy | IaC tool | Terraform |

---

## 📤 Outputs

| Output | Description |
|--------|-------------|
| resource_group_id | ID of the resource group |
| log_analytics_workspace_id | ID of the Log Analytics Workspace |
| app_insights_ids | Map of App Insights resource IDs |
| app_service_ids | Map of App Service resource IDs |
| action_group_id | ID of the Action Group |

---

## ⚠️ Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `Provider authentication failed` | Run `az login` and ensure correct subscription |
| `Resource name already exists` | Change `project_name` to unique value |
| `Quota exceeded` | Check subscription limits or use different region |
| `Resource lock prevents deletion` | Set `enable_resource_locks = false` or remove locks manually |

### Useful Commands

```bash
# Check Terraform state
terraform state list

# Show specific resource
terraform state show module.observability.azurerm_application_insights.apps[\"mywebapp\"]

# Refresh state from Azure
terraform refresh

# Import existing resource
terraform import module.observability.azurerm_resource_group.main[0] /subscriptions/.../resourceGroups/rg-name
```

---

## 📚 References

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Monitor Best Practices](https://learn.microsoft.com/en-us/azure/azure-monitor/best-practices)
- [Application Insights Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

