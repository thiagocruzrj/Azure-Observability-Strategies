# Azure Observability Strategies

[![Bicep](https://img.shields.io/badge/Bicep-0.27+-blue?logo=azure-devops)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
[![Azure Monitor](https://img.shields.io/badge/Azure%20Monitor-OpenTelemetry-green?logo=microsoft-azure)](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-overview)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **Monitoring Golden Path** implementation for Azure, providing production-ready Infrastructure as Code (IaC) for enterprise observability using Azure Monitor, Application Insights, and OpenTelemetry.

---

## 🎯 What This Repository Provides

| Component | Description |
|-----------|-------------|
| **IaC Modules** | Reusable Bicep modules for monitoring infrastructure |
| **Demo Apps** | .NET 9 Web + API + Azure Functions with distributed tracing |
| **Operational Layer** | Baseline alerts, action groups, and workbooks |
| **Documentation** | Step-by-step verification guides for each observability pillar |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MONITORING GOLDEN PATH                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                      │
│  │   Web App   │───▶│   API App   │───▶│  Function   │                      │
│  │  (.NET 9)   │    │  (.NET 9)   │    │ (.NET 8)    │                      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                      │
│         │                  │                  │                              │
│         │ OTel Distro      │ OTel Distro      │ OTel Mode                   │
│         ▼                  ▼                  ▼                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                      │
│  │ App Insights│    │ App Insights│    │ App Insights│                      │
│  │    (Web)    │    │    (API)    │    │   (Func)    │                      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                      │
│         │                  │                  │                              │
│         └──────────────────┼──────────────────┘                              │
│                            ▼                                                 │
│              ┌─────────────────────────┐                                    │
│              │  Log Analytics Workspace │◀─── Diagnostic Settings           │
│              │    (Unified Querying)    │     (Platform Logs)               │
│              └────────────┬────────────┘                                    │
│                           │                                                  │
│         ┌─────────────────┼─────────────────┐                               │
│         ▼                 ▼                 ▼                               │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐                        │
│  │   Alerts   │    │  Workbook  │    │   Policy   │                        │
│  │ (8 rules)  │    │ (Dashboard)│    │  (Tags)    │                        │
│  └────────────┘    └────────────┘    └────────────┘                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
Azure-Observability-Strategies/
│
├── main.bicep                    # 🎯 Main orchestration (subscription-scoped)
│
├── modules/                      # 📦 Reusable Bicep modules
│   ├── foundation.bicep          #    Resource Group + LAW
│   ├── appinsights.bicep         #    Workspace-based App Insights
│   ├── compute.bicep             #    App Service + Function App
│   ├── diagnosticSettings-websites.bicep
│   ├── ops-alerting-workbooks.bicep  # Alerts + Workbook (930+ lines)
│   ├── policy-tags.bicep         #    Tag enforcement policy
│   └── security-observability.bicep  # RBAC + PII policy
│
├── demo/                         # 🖥️ Demo applications
│   ├── Demo.Web/                 #    ASP.NET Core MVC (.NET 9)
│   ├── Demo.Api/                 #    ASP.NET Core Web API (.NET 9)
│   ├── Demo.Func/                #    Azure Functions (.NET 8 isolated)
│   └── DistributedTracingDemo.sln
│
├── docs/                         # 📚 Verification documentation
│   ├── step1-monitoring-strategy-verification.md
│   ├── step2-naming-tags-verification.md
│   ├── step3-tracing-dependencies-verification.md
│   ├── step4-sampling-verification.md
│   ├── step5-retention-costs-verification.md
│   ├── step6-auto-instrumentation-verification.md
│   ├── step7-governance-security-verification.md
│   ├── step8-operational-layer-verification.md
│   ├── verification-checklist.md     # Master checklist
│   ├── opentelemetry-standard.md
│   ├── cost-controls-standard.md
│   └── module-structure.md
│
├── examples/                     # 📋 Parameter file examples
│   └── ops-params-demo-dev.bicepparam
│
├── parameters/                   # ⚙️ Environment-specific parameters
│
└── scripts/                      # 🔧 Utility scripts
    └── verify-tracing.sh
```

---

## 🚀 Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (2.50+)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (0.27+)
- [.NET SDK 9.0](https://dotnet.microsoft.com/download/dotnet/9.0) (for demo apps)
- Azure subscription with Contributor access

### 1. Deploy Infrastructure

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "<your-subscription-id>"

# Deploy the monitoring stack (dev environment)
az deployment sub create \
  --location westeurope \
  --template-file main.bicep \
  --parameters env=dev \
  --parameters workload=myapp \
  --parameters owner=platform-team \
  --parameters costCenter=CC1234
```

### 2. Deploy Operational Layer (Alerts + Workbook)

```bash
# After infrastructure is deployed
az deployment group create \
  --resource-group rg-myapp-dev-weu \
  --template-file modules/ops-alerting-workbooks.bicep \
  --parameters examples/ops-params-demo-dev.bicepparam
```

### 3. Run Demo Applications Locally

```bash
cd demo

# Restore and build
dotnet restore
dotnet build

# Run all apps (requires 3 terminals or use the script)
./run-all.sh  # Linux/macOS
.\run-all.ps1 # Windows
```

---

## 📊 What Gets Deployed

| Resource Type | Naming Pattern | Purpose |
|---------------|----------------|---------|
| Resource Group | `rg-{workload}-{env}-{region}` | Container for all resources |
| Log Analytics Workspace | `law-{workload}-{env}-{region}` | Centralized log storage |
| Application Insights (×3) | `appi-{component}-{workload}-{env}-{region}` | Per-component telemetry |
| App Service Plan | `asp-{workload}-{env}-{region}` | Compute hosting |
| Web App | `app-web-{workload}-{env}-{region}` | Frontend application |
| API App | `app-api-{workload}-{env}-{region}` | Backend API |
| Function App | `func-{workload}-{env}-{region}` | Serverless processing |
| Action Group | `ag-mon-{env}-{workload}` | Alert notifications |
| Alert Rules (×8) | `alrt-{env}-{workload}-{component}-{signal}` | Proactive monitoring |
| Workbook | `wb-ops-{env}-{workload}` | Operations dashboard |
| Policy Assignment | `assign-require-tags-{env}-{workload}` | Tag governance |

---

## 🔔 Baseline Alerts Included

| Alert | Signal | Dev Threshold | Prod Threshold |
|-------|--------|---------------|----------------|
| Web 5xx Errors | HTTP 500+ responses | >10 in 15min | >5 in 15min |
| API 5xx Errors | HTTP 500+ responses | >10 in 15min | >5 in 15min |
| Web High Latency | Avg response time | >5000ms | >2000ms |
| API High Latency | Avg response time | >5000ms | >2000ms |
| Web Exceptions | Exception count | >20 in 15min | >5 in 15min |
| API Exceptions | Exception count | >20 in 15min | >5 in 15min |
| Function Failures | Failed executions | >10 in 15min | >3 in 15min |
| Function Exceptions | Exception count | >20 in 15min | >5 in 15min |

---

## 📖 Golden Path Steps

This repository implements an 8-step observability strategy:

| Step | Topic | Key Decisions |
|------|-------|---------------|
| **1** | [Monitoring Strategy](docs/step1-monitoring-strategy-verification.md) | Workspace-based App Insights, single LAW |
| **2** | [Naming & Tags](docs/step2-naming-tags-verification.md) | Consistent naming, 4 required tags |
| **3** | [Tracing](docs/step3-tracing-dependencies-verification.md) | W3C TraceContext, OTel distro |
| **4** | [Sampling](docs/step4-sampling-verification.md) | 100% dev, 10% prod |
| **5** | [Retention & Costs](docs/step5-retention-costs-verification.md) | 30-day dev, per-table tuning |
| **6** | [Auto-Instrumentation](docs/step6-auto-instrumentation-verification.md) | SDK-based (3 lines of code) |
| **7** | [Governance](docs/step7-governance-security-verification.md) | RBAC, PII policy, GDPR |
| **8** | [Operational Layer](docs/step8-operational-layer-verification.md) | Alerts, workbook, dashboard |

See the [Verification Checklist](docs/verification-checklist.md) for complete status.

---

## 🛠️ Key Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| Azure Bicep | 0.27+ | Infrastructure as Code |
| Azure Monitor | - | Observability platform |
| Application Insights | Workspace-based | APM and telemetry |
| OpenTelemetry | OTel Distro 1.3.0 | Distributed tracing |
| .NET | 9.0 (Web/API), 8.0 (Func) | Demo applications |
| Azure Functions | Isolated worker | Serverless compute |

---

## 📋 Environment Parameters

### Dev vs Prod Differences

| Setting | Dev | Prod |
|---------|-----|------|
| Log retention | 30 days | 90+ days |
| Sampling rate | 100% | 10% |
| Alert severity | Warning (Sev 2) | Critical (Sev 0) |
| Alert thresholds | Relaxed | Strict |
| Policy effect | Audit | Deny |

---

## 🔧 Useful Commands

```bash
# Check deployment status
az deployment sub show --name main --query "properties.provisioningState"

# List all resources in the resource group
az resource list -g rg-myapp-dev-weu -o table

# Query Application Insights
az monitor app-insights query \
  --app appi-web-myapp-dev-weu \
  --analytics-query "requests | take 10"

# Check alert rules
az monitor scheduled-query list -g rg-myapp-dev-weu -o table

# View policy compliance
az policy state summarize -g rg-myapp-dev-weu
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📚 Related Resources

- [Azure Monitor Documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/)
- [Application Insights Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [OpenTelemetry for .NET](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable)
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Well-Architected Framework - Operational Excellence](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/)

---

<p align="center">
  <strong>Built with ❤️ for Azure Observability</strong>
</p>
