@description('The principal ID of the managed identity to assign the Cognitive Services User role to')
param principalId string

@description('The name of the existing Azure AI Services account')
param aiServicesName string

// Built-in Cognitive Services User role definition ID
var cognitiveServicesUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a97b65f3-24c7-4388-baec-2e87135dc908'
)

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesName
}

resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, principalId, cognitiveServicesUserRoleId)
  scope: aiServices
  properties: {
    principalId: principalId
    roleDefinitionId: cognitiveServicesUserRoleId
    principalType: 'ServicePrincipal'
  }
}
