targetScope = 'resourceGroup'

@description('Name of the Postgres flexible server (must be globally unique)')
param pgServerName string

@description('Azure location for the server')
param location string = resourceGroup().location

@description('User Assigned Managed Identity Resource ID')
param managedIdentityId string

@description('User Assigned Managed Identity Principal ID (Object ID)')
param managedIdentityPrincipalId string

@description('Private Endpoint Subnet ID')
param privateEndpointSubnetId string

@description('Postgres version')
param postgresVersion string = '16'

@description('SKU Name (e.g., Standard_B2s, Standard_B1ms)')
param skuName string = 'Standard_B2s'

@description('SKU Tier: Burstable, GeneralPurpose, MemoryOptimized')
param skuTier string = 'Burstable'

@description('Storage size in GB')
param storageSizeGB int = 32

@description('Storage tier, e.g., P4')
param storageTier string = 'P4'

@description('IOPS for storage')
param iops int = 120

@description('Enable or disable storage auto grow')
param autoGrow string = 'Enabled'

@description('Backup retention days')
param backupRetentionDays int = 7

@description('Geo-redundant backup (Disabled or Enabled)')
param geoRedundantBackup string = 'Disabled'

@description('High availability mode (Disabled, ZoneRedundant, or SameZone)')
param highAvailabilityMode string = 'Disabled'

@description('Name of the database to create')
param databaseName string

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2025-01-01-preview' = {
  name: replace(toLower(pgServerName), '-', '')
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: postgresVersion
    network: {
      publicNetworkAccess: 'Disabled'
    }
    storage: {
      storageSizeGB: storageSizeGB
      iops: iops
      tier: storageTier
      autoGrow: autoGrow
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailabilityMode
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: subscription().tenantId
    }
  }
}

// Create database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-01-01-preview' = {
  parent: postgres
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Configure Managed Identity as Azure AD Administrator for PostgreSQL
resource postgresAdministrator 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2025-01-01-preview' = {
  parent: postgres
  name: managedIdentityPrincipalId
  properties: {
    principalType: 'ServicePrincipal'
    principalName: split(managedIdentityId, '/')[8]
    tenantId: subscription().tenantId
  }
}

// ---------------------------
// Private Endpoint for PostgreSQL
// NOTE: DNS is managed by WTW automation - do NOT integrate with Private DNS Zone
// See: https://wtw.sharepoint.com/sites/KnowledgeHub/SitePages/Private-Endpoint-Automation.aspx
// ---------------------------
resource postgresPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${pgServerName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${pgServerName}-connection'
        properties: {
          privateLinkServiceId: postgres.id
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }
}

output postgresServerName string = postgres.name
output postgresServerResourceId string = postgres.id
output postgresServerFQDN string = postgres.properties.fullyQualifiedDomainName
output databaseName string = database.name
output postgresPrivateEndpointId string = postgresPrivateEndpoint.id
