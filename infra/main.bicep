// ------------------------------------------------------------------
// Main Bicep orchestration template for ZavaStorefront
// Deploys all infrastructure into a single resource group in westus3
// ------------------------------------------------------------------

targetScope = 'resourceGroup'

// ------------------------------------------------------------------
// Parameters
// ------------------------------------------------------------------

@description('The Azure region for all resources')
param location string = 'westus3'

@description('The environment name (e.g., dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string = 'dev'

@description('Base name used to derive resource names')
@minLength(3)
@maxLength(12)
param baseName string = 'zavastore'

// ------------------------------------------------------------------
// Variables — all resource names computed centrally
// ------------------------------------------------------------------

var uniqueSuffix = uniqueString(resourceGroup().id)

// Log Analytics & Monitoring
var logAnalyticsName = 'log-${baseName}-${environmentName}-${take(uniqueSuffix, 6)}'
var appInsightsName = 'appi-${baseName}-${environmentName}-${take(uniqueSuffix, 6)}'

// Container Registry (alphanumeric only, max 50 chars)
var acrName = 'acr${baseName}${environmentName}${take(uniqueSuffix, 6)}'

// App Service
var appServicePlanName = 'plan-${baseName}-${environmentName}'
var webAppName = 'app-${baseName}-${environmentName}-${take(uniqueSuffix, 6)}'

// AI Foundry & dependencies
var aiServicesName = 'ai-${baseName}-${environmentName}-${take(uniqueSuffix, 6)}'
var aiStorageAccountName = 'st${baseName}${take(uniqueSuffix, 8)}'
var aiKeyVaultName = 'kv-${baseName}-${take(uniqueSuffix, 6)}'
var aiHubName = 'aihub-${baseName}-${environmentName}'
var aiProjectName = 'aiproj-${baseName}-${environmentName}'

// ------------------------------------------------------------------
// Modules
// ------------------------------------------------------------------

// 1. Log Analytics Workspace
module logAnalytics 'modules/logAnalytics.bicep' = {
  params: {
    location: location
    workspaceName: logAnalyticsName
  }
}

// 2. Application Insights (workspace-based)
module appInsights 'modules/appInsights.bicep' = {
  params: {
    location: location
    appInsightsName: appInsightsName
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// 3. Azure Container Registry
module acr 'modules/acr.bicep' = {
  params: {
    location: location
    acrName: acrName
  }
}

// 4. Linux App Service (Web App for Containers)
module appService 'modules/appService.bicep' = {
  params: {
    location: location
    appServicePlanName: appServicePlanName
    webAppName: webAppName
    acrLoginServer: acr.outputs.loginServer
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    aiServicesEndpoint: aiFoundry.outputs.aiServicesEndpoint
    aiContentSafetyEndpoint: aiFoundry.outputs.aiServicesContentSafetyEndpoint
  }
}

// 5. AcrPull role assignment — Web App managed identity → ACR
module acrPullRole 'modules/roleAssignment.bicep' = {
  params: {
    principalId: appService.outputs.principalId
    acrName: acr.outputs.name
  }
}

// 6. AI Foundry (AI Services, Hub, Project, model deployments)
module aiFoundry 'modules/aiFoundry.bicep' = {
  params: {
    location: location
    aiServicesName: aiServicesName
    storageAccountName: aiStorageAccountName
    keyVaultName: aiKeyVaultName
    aiHubName: aiHubName
    aiProjectName: aiProjectName
    appInsightsId: appInsights.outputs.id
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// 7. Cognitive Services OpenAI User role — Web App managed identity → AI Services
module aiServicesRole 'modules/aiServicesRoleAssignment.bicep' = {
  params: {
    principalId: appService.outputs.principalId
    aiServicesName: aiFoundry.outputs.aiServicesName
  }
}

// 8. Azure Workbook — AI Services Observability
module observabilityWorkbook 'modules/workbook.bicep' = {
  params: {
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// ------------------------------------------------------------------
// Outputs (consumed by AZD and CI/CD)
// ------------------------------------------------------------------

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.name
output AZURE_APP_SERVICE_WEB_NAME string = appService.outputs.webAppName
output WEB_URI string = appService.outputs.webAppUrl
output AZURE_APP_INSIGHTS_NAME string = appInsights.outputs.name
output AZURE_AI_SERVICES_ENDPOINT string = aiFoundry.outputs.aiServicesEndpoint
output AZURE_AI_HUB_NAME string = aiFoundry.outputs.aiHubName
output AZURE_AI_PROJECT_NAME string = aiFoundry.outputs.aiProjectName
