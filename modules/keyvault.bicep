targetScope = 'resourceGroup'

@description('Location for Key Vault')
param location string = resourceGroup().location

@description('Name of the Key Vault')
param keyVaultName string

@description('Azure tenant ID. Defaults to current subscription tenant.')
param tenantId string = subscription().tenantId

@description('Enable Azure RBAC authorization for Key Vault')
param enableRbacAuthorization bool = true

@description('Key Vault SKU: standard or premium')
param keyVaultSku string = 'standard'

@description('Key Vault SKU family')
param keyVaultFamily string = 'A'

@description('Default action for network ACLs (Allow or Deny)')
param networkAclsDefaultAction string = 'Deny'

@description('Network ACLs bypass settings (AzureServices, None, or list with comma separation)')
param networkAclsBypass string = 'AzureServices'

@description('Container App Subnet ID')
param containerAppSubnetId string

@description('Enable private endpoint for Key Vault')
param enablePrivateEndpoint bool = false

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string = ''

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: true
    enablePurgeProtection: true
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    sku: {
      name: keyVaultSku
      family: keyVaultFamily
    }
    networkAcls: {
      defaultAction: networkAclsDefaultAction
      bypass: networkAclsBypass
      virtualNetworkRules: !enablePrivateEndpoint ? [
        {
          id: containerAppSubnetId
          ignoreMissingVnetServiceEndpoint: false
        }
      ] : []
    }
  }
}

// ---------------------------
// Private Endpoint for Key Vault (if enabled)
// NOTE: DNS is managed by WTW automation - do NOT integrate with Private DNS Zone
// See: https://wtw.sharepoint.com/sites/KnowledgeHub/SitePages/Private-Endpoint-Automation.aspx
// ---------------------------
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if (enablePrivateEndpoint) {
  name: '${keyVaultName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-connection'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

output keyVaultId string = kv.id
output keyVaultName string = kv.name
output keyVaultPrivateEndpointId string = enablePrivateEndpoint ? kvPrivateEndpoint.id : ''
