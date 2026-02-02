Step A — Create shared monitoring resources

Create Resource Group

Name: rg-obs-demo-dev-weu

Region: West Europe

Tags (required): env=dev, workload=obs-demo, owner=<you>, costCenter=<id>

Create Log Analytics Workspace (LAW)

Name: law-obs-demo-dev-weu

RG: rg-obs-demo-dev-weu

Retention (dev suggestion): 14 days (you can set 30 if you want)

Create 3 workspace-based Application Insights (one per component)
Create each as workspace-based and attach to the LAW:

appi-web-demo-dev-weu

appi-api-demo-dev-weu

appi-func-demo-dev-weu

Copy connection strings (you will use app settings later)
For each App Insights:

App Insights → Properties → copy Connection string
✅ Use connection strings everywhere (no instrumentation keys)