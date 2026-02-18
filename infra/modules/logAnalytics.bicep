@description('The location for the Log Analytics workspace')
param location string

@description('The name of the Log Analytics workspace')
param workspaceName string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output workspaceId string = logAnalytics.id
output name string = logAnalytics.name
