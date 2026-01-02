targetScope = 'resourceGroup'

@description('Name of the existing VNet')
param vnetName string

@description('Name of the subnet for Container Apps')
param containerAppSubnetName string

@description('Address prefix for Container App subnet')
param containerAppSubnetAddress string

@description('Name of the subnet for databases')
param dbSubnetName string

@description('Address prefix for database subnet')
param dbSubnetAddress string

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}

resource containerAppSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  parent: existingVnet
  name: containerAppSubnetName
  properties: {
    addressPrefix: containerAppSubnetAddress
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.Storage'
      }
    ]
    delegations: [
      {
        name: 'Microsoft.App.environments'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}

resource dbSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  parent: existingVnet
  name: dbSubnetName
  properties: {
    addressPrefix: dbSubnetAddress
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    containerAppSubnet
  ]
}

output containerAppSubnetId string = containerAppSubnet.id
output dbSubnetId string = dbSubnet.id
