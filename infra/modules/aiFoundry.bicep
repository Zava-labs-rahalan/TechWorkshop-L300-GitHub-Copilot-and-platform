@description('The location for AI resources')
param location string

@description('The name of the Azure AI Services account')
param aiServicesName string

@description('The name of the Storage Account for AI Foundry Hub')
param storageAccountName string

@description('The name of the Key Vault for AI Foundry Hub')
param keyVaultName string

@description('The name of the AI Foundry Hub')
param aiHubName string

@description('The name of the AI Foundry Project')
param aiProjectName string

@description('The Application Insights resource ID (for AI Hub telemetry)')
param appInsightsId string

@description('The Log Analytics workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string

// ------------------------------------------------------------------
// Storage Account (required dependency for AI Foundry Hub)
// ------------------------------------------------------------------
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    allowSharedKeyAccess: false
  }
}

// ------------------------------------------------------------------
// Key Vault (required dependency for AI Foundry Hub)
// ------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// ------------------------------------------------------------------
// Azure AI Services account (hosts model deployments)
// ------------------------------------------------------------------
resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: aiServicesName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

// ------------------------------------------------------------------
// GPT-4 model deployment
// ------------------------------------------------------------------
resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: 'gpt-4.1'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1'
    }
  }
}

// ------------------------------------------------------------------
// Phi model deployment (deployed sequentially after GPT-4)
// ------------------------------------------------------------------
resource phiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: 'phi-4'
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'Microsoft'
      name: 'Phi-4-mini-instruct'
      version: '1'
    }
  }
  dependsOn: [gpt4Deployment]
}

// ------------------------------------------------------------------
// AI Foundry Hub
// ------------------------------------------------------------------
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: aiHubName
  location: location
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'Zava Storefront AI Hub'
    description: 'AI Foundry hub for ZavaStorefront dev environment'
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: appInsightsId
  }
}

// ------------------------------------------------------------------
// AI Foundry Hub → AI Services connection
// ------------------------------------------------------------------
resource aiHubConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: aiHub
  name: 'ai-services-connection'
  properties: {
    category: 'AIServices'
    target: aiServices.properties.endpoint
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServices.id
    }
  }
}

// ------------------------------------------------------------------
// AI Foundry Project (workspace for model experimentation)
// ------------------------------------------------------------------
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: aiProjectName
  location: location
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'Zava Storefront AI Project'
    description: 'AI Foundry project for ZavaStorefront dev environment'
    hubResourceId: aiHub.id
  }
}

// ------------------------------------------------------------------
// Diagnostic Settings — AI Services account
// ------------------------------------------------------------------
resource aiServicesDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aiServicesName}-diag'
  scope: aiServices
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ------------------------------------------------------------------
// Diagnostic Settings — AI Foundry Hub
// ------------------------------------------------------------------
resource aiHubDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aiHubName}-diag'
  scope: aiHub
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output aiServicesEndpoint string = aiServices.properties.endpoint
output aiServicesId string = aiServices.id
output aiServicesName string = aiServices.name
output aiHubName string = aiHub.name
output aiProjectName string = aiProject.name
