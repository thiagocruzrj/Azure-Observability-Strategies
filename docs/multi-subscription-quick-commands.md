# Azure Multi-Subscription Audit - Quick Commands Reference
> One-liner commands to audit monitoring across all subscriptions in your tenant

## 🚀 Quick Start

### List All Subscriptions
```bash
# Bash/Azure CLI
az account list --query "[?state=='Enabled'].{name:name, id:id}" -o table

# PowerShell
az account list | ConvertFrom-Json | Where-Object state -eq 'Enabled' | Select-Object name, id
```

---

## 📊 Cross-Subscription Queries (Azure Resource Graph)

> **Fastest method** - Uses Azure Resource Graph for instant cross-subscription queries
>
> ⚠️ **CRITICAL NOTES**:  
> 1. By default, `az graph query` only queries the **current subscription**!  
> 2. You **MUST** include `--subscriptions $ALL_SUBS` to query all subscriptions.
> 3. Use `=~` (case-insensitive) instead of `==` for type matching
> 4. Add `--first 1000` to get all results (default pagination limits results)
> 5. Add `--query "data"` to extract actual results (otherwise you get just metadata!)

### Setup: Store All Subscription IDs
```bash
# Run this FIRST - store all subscription IDs for reuse
# Note: tr -d '\r' removes Windows carriage returns (needed in Git Bash/WSL)
ALL_SUBS=$(az account list --query "[?state=='Enabled'].id" -o tsv | tr -d '\r' | tr '\n' ' ')

# Verify it worked
echo "Found $(echo $ALL_SUBS | wc -w) subscriptions"
```

### Count All Resources by Subscription
```bash
az graph query -q "Resources | summarize Total=count() by subscriptionId | order by Total desc" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### App Services by Type (Web App, Function App, API App)
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.web/sites'
| extend appType = case(
    kind contains 'functionapp', 'Function App',
    kind contains 'api', 'API App',
    'Web App')
| summarize Total=count() by appType
| order by Total desc" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### All Application Insights Across Tenant
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.insights/components' 
| project name, subscriptionId, resourceGroup, location, properties.IngestionMode, properties.WorkspaceResourceId" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### Find Classic App Insights (Need Migration!)
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.insights/components' 
| where isnull(properties.WorkspaceResourceId) or properties.WorkspaceResourceId == ''
| project name, subscriptionId, resourceGroup, location" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### All Log Analytics Workspaces
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.operationalinsights/workspaces' 
| project name, subscriptionId, resourceGroup, properties.retentionInDays, sku=properties.sku.name" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### All Alert Rules
```bash
az graph query -q "Resources 
| where type in~ ('microsoft.insights/metricalerts', 'microsoft.insights/scheduledqueryrules', 'microsoft.insights/activitylogalerts')
| summarize Total=count() by subscriptionId, type" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### App Services Without Monitoring
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.web/sites'
| where isnull(properties.siteConfig.appSettings)
| project name, subscriptionId, resourceGroup" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### Resources Missing Tags
```bash
# Missing 'env' tag
az graph query -q "Resources 
| where isnull(tags['env']) or tags['env'] == ''
| summarize Total=count() by subscriptionId, type | order by Total desc" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Missing 'owner' tag
az graph query -q "Resources 
| where isnull(tags['owner']) or tags['owner'] == ''
| summarize Total=count() by subscriptionId | order by Total desc" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### Diagnostic Settings Audit
```bash
az graph query -q "ResourceContainers 
| where type =~ 'microsoft.resources/subscriptions' 
| project subscriptionId, subscriptionName=name" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

---

## 🔄 Loop Through All Subscriptions

### Bash - Simple Loop
```bash
# Get all App Insights across all subs
for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
    echo "=== Subscription: $sub ===" 
    az account set -s $sub
    az monitor app-insights component list -o table 2>/dev/null
done
```

### Bash - Parallel Execution (5 at a time)
```bash
export -f audit_sub
audit_sub() {
    az account set -s $1
    az monitor metrics alert list --query "[].{name:name,enabled:enabled}" -o json
}

az account list --query "[?state=='Enabled'].id" -o tsv | \
    xargs -P 5 -I {} bash -c 'audit_sub "$@"' _ {}
```

### PowerShell - Simple Loop
```powershell
$subs = az account list | ConvertFrom-Json | Where-Object state -eq 'Enabled'
foreach ($sub in $subs) {
    Write-Host "=== $($sub.name) ===" -ForegroundColor Cyan
    az account set -s $sub.id
    az monitor app-insights component list -o table
}
```

### PowerShell - Parallel (PS 7+)
```powershell
$subs = az account list | ConvertFrom-Json | Where-Object state -eq 'Enabled'
$subs | ForEach-Object -Parallel {
    az account set -s $_.id
    $alerts = az monitor metrics alert list | ConvertFrom-Json
    [PSCustomObject]@{
        Subscription = $_.name
        AlertCount = $alerts.Count
    }
} -ThrottleLimit 5 | Format-Table
```

---

## 📈 Specific Audit Queries

### Count Alerts per Subscription
```bash
for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
    az account set -s $sub
    name=$(az account show --query name -o tsv)
    metric=$(az monitor metrics alert list --query "length(@)" -o tsv 2>/dev/null || echo 0)
    query=$(az monitor scheduled-query list --query "length(@)" -o tsv 2>/dev/null || echo 0)
    echo "$name: Metric=$metric, Query=$query"
done
```

### Export All Alerts to JSON
```bash
mkdir -p audit-export
for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
    az account set -s $sub
    name=$(az account show --query name -o tsv | tr ' ' '_')
    az monitor metrics alert list -o json > "audit-export/${name}-metric-alerts.json"
    az monitor scheduled-query list -o json > "audit-export/${name}-query-alerts.json"
done
```

### Check Action Groups Configuration
```bash
for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
    az account set -s $sub
    echo "=== $(az account show --query name -o tsv) ==="
    az monitor action-group list --query "[].{name:name, emailReceivers:emailReceivers[].name, webhooks:length(webhookReceivers)}" -o table
done
```

### LAW Retention Settings
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.operationalinsights/workspaces' 
| project name, subscriptionId, retention=properties.retentionInDays, sku=properties.sku.name
| order by retention asc" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

---

## 🔍 Security & Compliance

### Check Diagnostic Settings on Key Vault
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.keyvault/vaults' 
| project name, subscriptionId, resourceGroup" --subscriptions $ALL_SUBS --first 1000 --query "data" -o json | \
jq -r '.[] | "\(.subscriptionId) \(.resourceGroup) \(.name)"' | \
while read sub rg name; do
    az account set -s $sub
    diag=$(az monitor diagnostic-settings list --resource-group $rg --resource $name --resource-type Microsoft.KeyVault/vaults --query "length(@)" -o tsv 2>/dev/null || echo 0)
    echo "$name (${sub:0:8}...): $diag diagnostic settings"
done
```

### Policy Compliance Summary
```bash
for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
    az account set -s $sub
    name=$(az account show --query name -o tsv)
    compliant=$(az policy state summarize --query "results.resourceDetails[?complianceState=='Compliant'].count | [0]" -o tsv 2>/dev/null || echo 0)
    noncompliant=$(az policy state summarize --query "results.resourceDetails[?complianceState=='NonCompliant'].count | [0]" -o tsv 2>/dev/null || echo 0)
    echo "$name: Compliant=$compliant, NonCompliant=$noncompliant"
done
```

---

## 📁 Export to CSV

### All Resources to CSV
```bash
az graph query -q "Resources | project name, type, subscriptionId, resourceGroup, location" \
    --first 5000 -o json | \
jq -r '["Name","Type","SubscriptionId","ResourceGroup","Location"], (.[] | [.name, .type, .subscriptionId, .resourceGroup, .location]) | @csv' > all-resources.csv
```

### App Insights to CSV
```bash
az graph query -q "Resources 
| where type =~ 'microsoft.insights/components' 
| project name, subscriptionId, resourceGroup, ingestionMode=properties.IngestionMode, workspaceId=properties.WorkspaceResourceId" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o json | \
jq -r '["Name","SubscriptionId","ResourceGroup","IngestionMode","WorkspaceId"], (.[] | [.name, .subscriptionId, .resourceGroup, .ingestionMode, .workspaceId]) | @csv' > app-insights.csv
```

---

## 🛠️ Utility Commands

### Set Default Subscription
```bash
az account set --subscription "subscription-name-or-id"
```

### Get Current Context
```bash
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table
```

### List Available Regions
```bash
az account list-locations --query "[].{name:name, displayName:displayName}" -o table
```

### Check CLI Version
```bash
az version -o table
```

---

## 📝 Full Audit Script Usage

### Bash (Linux/macOS/WSL)
```bash
chmod +x scripts/multi-subscription-audit.sh
./scripts/multi-subscription-audit.sh

# With custom output directory
OUTPUT_DIR="my-audit" ./scripts/multi-subscription-audit.sh

# With parallel jobs
PARALLEL_JOBS=10 ./scripts/multi-subscription-audit.sh
```

### PowerShell (Windows)
```powershell
.\scripts\multi-subscription-audit.ps1

# With custom output directory
.\scripts\multi-subscription-audit.ps1 -OutputDir "my-audit"

# With throttle limit
.\scripts\multi-subscription-audit.ps1 -ThrottleLimit 10
```

---

## 💡 Pro Tips

1. **Use Resource Graph** for fastest cross-subscription queries (no subscription switching)
2. **Parallel execution** with `-P` (bash) or `-Parallel` (PowerShell) for speed
3. **Export to JSON** for detailed analysis, use **jq** for processing
4. **Schedule weekly audits** using Azure Automation or GitHub Actions
5. **Cache results** to avoid repeated API calls during analysis
