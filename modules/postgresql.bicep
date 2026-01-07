targetScope = 'resourceGroup'

@description('Name of the Cosmos DB for PostgreSQL cluster (must be globally unique)')
param clusterName string

@description('Azure location for the cluster')
param location string = resourceGroup().location

@description('Administrator login password')
@secure()
param administratorLoginPassword string

@description('PostgreSQL version')
param postgresVersion string = '16'

@description('Node count (0 for single node cluster, 1+ for multi-node)')
param nodeCount int = 0

@description('Coordinator vCores (2, 4, 8, 16, 32, 64)')
param coordinatorVCores int = 2

@description('Coordinator storage in MiB')
param coordinatorStorageQuotaInMb int = 131072

@description('Node vCores (only if nodeCount > 0)')
param nodeVCores int = 2

@description('Node storage in MiB (only if nodeCount > 0)')
param nodeStorageQuotaInMb int = 131072

@description('Enable high availability')
param enableHa bool = false

@description('Private Endpoint Subnet ID')
param privateEndpointSubnetId string

resource cosmosPostgres 'Microsoft.DBforPostgreSQL/serverGroupsv2@2022-11-08' = {
  name: replace(toLower(clusterName), '-', '')
  location: location
  properties: {
    postgresqlVersion: postgresVersion
    administratorLoginPassword: administratorLoginPassword
    enableHa: enableHa
    coordinatorVCores: coordinatorVCores
    coordinatorStorageQuotaInMb: coordinatorStorageQuotaInMb
    coordinatorEnablePublicIpAccess: false
    nodeCount: nodeCount
    nodeVCores: nodeVCores
    nodeStorageQuotaInMb: nodeStorageQuotaInMb
    nodeEnablePublicIpAccess: false
  }
}

// ---------------------------
// Private Endpoint for Cosmos DB for PostgreSQL
// NOTE: DNS is managed by WTW automation - do NOT integrate with Private DNS Zone
// See: https://wtw.sharepoint.com/sites/KnowledgeHub/SitePages/Private-Endpoint-Automation.aspx
// ---------------------------
resource cosmosPostgresPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${clusterName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${clusterName}-connection'
        properties: {
          privateLinkServiceId: cosmosPostgres.id
          groupIds: [
            'coordinator'
          ]
        }
      }
    ]
  }
}

output clusterName string = cosmosPostgres.name
output clusterResourceId string = cosmosPostgres.id
output clusterEndpoint string = cosmosPostgres.properties.serverNames[0].fullyQualifiedDomainName
output privateEndpointId string = cosmosPostgresPrivateEndpoint.id
