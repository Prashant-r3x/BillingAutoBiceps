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

@description('List of PrincipalIds to assign RBAC role')
param principalIds array

@description('RBAC role definition ID (default: Key Vault Secrets User)')
param keyVaultRoleDefinitionId string = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

@description('Container App Subnet ID')
param containerAppSubnetId string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: true
    enablePurgeProtection: true
    sku: {
      name: keyVaultSku
      family: keyVaultFamily
    }
    networkAcls: {
      defaultAction: networkAclsDefaultAction
      bypass: networkAclsBypass
      virtualNetworkRules: [
        {
          id: containerAppSubnetId
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
  }
}

// Assign roles to principal Ids
resource kvRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in principalIds: {
  name: guid(kv.id, principalId, keyVaultRoleDefinitionId)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultRoleDefinitionId)
    principalId: principalId
  }
}]

output keyVaultId string = kv.id
output keyVaultName string = kv.name
