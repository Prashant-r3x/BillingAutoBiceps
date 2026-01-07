targetScope = 'resourceGroup'

@description('ACR name (globally unique)')
param acrName string

@description('Location')
param location string = resourceGroup().location

@description('SKU: Basic, Standard, Premium')
param acrSku string = 'Standard'

@description('Enable admin user?')
param enableAdmin bool = false

@description('Enable private endpoint for ACR (only for Standard or Premium SKU)')
param enablePrivateEndpoint bool = false

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string = ''

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: replace(toLower(acrName), '-', '')
  location: location
  tags: {
    'acrnetexclude': 'UC2'
  }
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: enableAdmin
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// ---------------------------
// Private Endpoint for ACR (only if enabled and Premium/Standard SKU)
// NOTE: DNS is managed by WTW automation - do NOT integrate with Private DNS Zone
// See: https://wtw.sharepoint.com/sites/KnowledgeHub/SitePages/Private-Endpoint-Automation.aspx
// ---------------------------
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if (enablePrivateEndpoint && (acrSku == 'Premium' || acrSku == 'Standard')) {
  name: '${acrName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${acrName}-connection'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output acrPrivateEndpointId string = enablePrivateEndpoint ? acrPrivateEndpoint.id : ''
