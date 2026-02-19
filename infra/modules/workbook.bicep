@description('The location for the workbook resource')
param location string

@description('The display name of the workbook')
param workbookDisplayName string = 'AI Services Observability'

@description('The resource ID of the Log Analytics workspace used as the data source')
param logAnalyticsWorkspaceId string

// ------------------------------------------------------------------
// Workbook — AI Services Observability
// Visualizes request volume, latency percentiles, and operation
// breakdown for Azure AI / Cognitive Services diagnostic logs.
// ------------------------------------------------------------------

var workbookContent = loadTextContent('workbook.json')

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, 'ai-services-observability')
  location: location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    category: 'workbook'
    sourceId: logAnalyticsWorkspaceId
    serializedData: workbookContent
  }
}

output workbookId string = workbook.id
output workbookName string = workbook.name
