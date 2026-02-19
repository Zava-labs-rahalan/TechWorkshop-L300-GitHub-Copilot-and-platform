@description('The location for the App Service resources')
param location string

@description('The name of the App Service Plan')
param appServicePlanName string

@description('The name of the Web App')
param webAppName string

@description('The ACR login server URL (e.g., myacr.azurecr.io)')
param acrLoginServer string

@description('Application Insights connection string for monitoring')
param appInsightsConnectionString string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('The Azure AI Services endpoint URL')
param aiServicesEndpoint string

@description('The AI model deployment name')
param aiModelDeploymentName string = 'phi-4'

@description('The Docker image name (without registry prefix or tag)')
param dockerImageName string = 'zava-storefront'

@description('The Docker image tag')
param dockerImageTag string = 'latest'

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true // Required for Linux App Service Plans
  }
}

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  tags: {
    'azd-service-name': 'web'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/${dockerImageName}:${dockerImageTag}'
      acrUseManagedIdentityCreds: true
      alwaysOn: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrLoginServer}'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '80'
        }
        {
          name: 'AzureAI__Endpoint'
          value: aiServicesEndpoint
        }
        {
          name: 'AzureAI__ModelDeploymentName'
          value: aiModelDeploymentName
        }
      ]
    }
  }
}

output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output principalId string = webApp.identity.principalId
