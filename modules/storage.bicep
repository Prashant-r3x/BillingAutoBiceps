targetScope = 'resourceGroup'

@description('Name of the Storage Account (must be globally unique, lowercase, 3–24 characters)')
param storageAccountName string

@description('Location for the Storage Account')
param location string = resourceGroup().location

@description('Replication type: LRS, GRS, RAGRS, ZRS')
param replicationType string = 'LRS'

@description('Storage account SKU (Standard or Premium)')
param sku string = 'Standard'

@description('Access tier: Hot or Cool (only valid for BlobStorage and general-purpose v2 accounts)')
param accessTier string = 'Hot'

@description('Subnet ID for private endpoint')
param subnetId string = ''

@description('Enable private endpoint (default: false)')
param enablePrivateEndpoint bool = false

@description('Container App subnet ID for service endpoint access')
param containerAppSubnetId string = ''

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: '${sku}_${replicationType}'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    accessTier: accessTier
    supportsHttpsTrafficOnly: true
    networkAcls: {
      resourceAccessRules: []
      bypass: 'AzureServices'
      virtualNetworkRules: !empty(containerAppSubnetId) ? [
        {
          id: containerAppSubnetId
          action: 'Allow'
        }
      ] : []
      ipRules: []
      defaultAction: 'Deny'
    }
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob service with soft delete enabled
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// ---------------------------
// Private Endpoints for Blob and File Storage (if enabled)
// NOTE: DNS is managed by WTW automation - do NOT integrate with Private DNS Zone
// See: https://wtw.sharepoint.com/sites/KnowledgeHub/SitePages/Private-Endpoint-Automation.aspx
// ---------------------------
resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = if (enablePrivateEndpoint) {
  name: '${storageAccountName}-blob-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-blob-connection'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

output storageAccountId string = storage.id
output blobEndpoint string = storage.properties.primaryEndpoints.blob
output storageAccountName string = storage.name
output blobPrivateEndpointId string = enablePrivateEndpoint ? blobPrivateEndpoint.id : ''
