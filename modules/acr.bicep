targetScope = 'resourceGroup'

@description('ACR name (globally unique)')
param acrName string

@description('Location')
param location string = resourceGroup().location

@description('SKU: Basic, Standard, Premium')
param acrSku string = 'Standard'

@description('Enable admin user?')
param enableAdmin bool = false

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
    publicNetworkAccess: 'Enabled'
    networkRuleSet: {
      defaultAction: 'Allow'
    }
  }
}

output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
