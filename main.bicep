targetScope = 'resourceGroup'

@description('Azure location for resources')
param location string = resourceGroup().location

// ========================================
// VNet and Subnet Parameters
// ========================================
@description('Name of the existing VNet')
param vnetName string

@description('Name of the subnet for Container Apps')
param containerAppSubnetName string

@description('Address prefix for Container App subnet (e.g., 10.58.52.0/28)')
param containerAppSubnetAddress string

@description('Name of the subnet for private endpoints')
param privateEndpointSubnetName string

@description('Address prefix for private endpoint subnet (e.g., 10.58.52.64/27)')
param privateEndpointSubnetAddress string

// ========================================
// Managed Identity Parameters
// ========================================
@description('Name of the user-assigned managed identity')
param managedIdentityName string

// ========================================
// Log Analytics Parameters
// ========================================
@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

@description('Log Analytics SKU')
param logAnalyticsSku string = 'PerGB2018'

@description('Log Analytics retention in days')
param logAnalyticsRetentionDays int = 30

// ========================================
// ACR Parameters
// ========================================
@description('Azure Container Registry name')
param acrName string

@description('ACR SKU: Basic, Standard, Premium')
param acrSku string = 'Standard'

@description('Enable admin user for ACR')
param acrEnableAdmin bool = false

@description('Enable private endpoint for ACR')
param acrEnablePrivateEndpoint bool = false

// ========================================
// Cosmos DB for PostgreSQL Parameters
// ========================================
@description('Cosmos DB for PostgreSQL cluster name')
param pgClusterName string

@description('PostgreSQL version')
param postgresVersion string = '16'

@description('Administrator login password')
@secure()
param pgAdminPassword string

@description('Node count (0 for single node, 1+ for multi-node)')
param pgNodeCount int = 0

@description('Coordinator vCores')
param pgCoordinatorVCores int = 2

@description('Coordinator storage in MiB')
param pgCoordinatorStorageMb int = 131072

@description('Node vCores')
param pgNodeVCores int = 2

@description('Node storage in MiB')
param pgNodeStorageMb int = 131072

@description('Enable high availability')
param pgEnableHa bool = false

// ========================================
// Key Vault Parameters
// ========================================
@description('Key Vault name')
param keyVaultName string

@description('Key Vault SKU')
param keyVaultSku string = 'standard'

@description('Key Vault network ACLs default action')
param kvNetworkAclsDefaultAction string = 'Deny'

@description('Enable private endpoint for Key Vault')
param kvEnablePrivateEndpoint bool = false

// ========================================
// Storage Account Parameters
// ========================================
@description('Storage account name')
param storageAccountName string

@description('Storage replication type')
param storageReplicationType string = 'LRS'

@description('Storage SKU')
param storageSku string = 'Standard'

@description('Storage access tier')
param storageAccessTier string = 'Hot'

@description('Enable private endpoint for storage')
param storageEnablePrivateEndpoint bool = false

// ========================================
// Container App Environment Parameters
// ========================================
@description('Container App Environment name')
param containerAppEnvName string

@description('Workload profile name')
param workloadProfileName string = 'Consumption'

@description('Workload profile type')
param workloadProfileType string = 'Consumption'

@description('Use internal-only environment')
param containerAppInternal bool = true

// ========================================
// Create Subnets in VNet
// ========================================
module subnetsModule 'modules/subnets.bicep' = {
  name: 'subnets-deployment'
  params: {
    vnetName: vnetName
    containerAppSubnetName: containerAppSubnetName
    containerAppSubnetAddress: containerAppSubnetAddress
    privateEndpointSubnetName: privateEndpointSubnetName
    privateEndpointSubnetAddress: privateEndpointSubnetAddress
  }
}

// ========================================
// Create Managed Identity
// ========================================
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

// ========================================
// Create Log Analytics Workspace
// ========================================
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: logAnalyticsRetentionDays
  }
}

// ========================================
// Deploy ACR Module
// ========================================
module acrModule 'modules/acr.bicep' = {
  name: 'acr-deployment'
  params: {
    acrName: acrName
    location: location
    acrSku: acrSku
    enableAdmin: acrEnableAdmin
    enablePrivateEndpoint: acrEnablePrivateEndpoint
    privateEndpointSubnetId: subnetsModule.outputs.privateEndpointSubnetId
  }
}

// ========================================
// Deploy Cosmos DB for PostgreSQL Module
// ========================================
module postgresModule 'modules/postgresql.bicep' = {
  name: 'postgres-deployment'
  params: {
    clusterName: pgClusterName
    location: location
    administratorLoginPassword: pgAdminPassword
    postgresVersion: postgresVersion
    nodeCount: pgNodeCount
    coordinatorVCores: pgCoordinatorVCores
    coordinatorStorageQuotaInMb: pgCoordinatorStorageMb
    nodeVCores: pgNodeVCores
    nodeStorageQuotaInMb: pgNodeStorageMb
    enableHa: pgEnableHa
    privateEndpointSubnetId: subnetsModule.outputs.privateEndpointSubnetId
  }
}

// ========================================
// Deploy Container App Environment Module
// ========================================
module containerAppEnvModule 'modules/container-app-env.bicep' = {
  name: 'container-app-env-deployment'
  params: {
    location: location
    containerAppEnvName: containerAppEnvName
    appSubnetId: subnetsModule.outputs.containerAppSubnetId
    workloadProfileName: workloadProfileName
    workloadProfileType: workloadProfileType
    internal: containerAppInternal
    managedIdentityId: managedIdentity.id
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

// ========================================
// Deploy Key Vault Module
// ========================================
module keyVaultModule 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    location: location
    keyVaultName: keyVaultName
    keyVaultSku: keyVaultSku
    networkAclsDefaultAction: kvNetworkAclsDefaultAction
    containerAppSubnetId: subnetsModule.outputs.containerAppSubnetId
    enablePrivateEndpoint: kvEnablePrivateEndpoint
    privateEndpointSubnetId: subnetsModule.outputs.privateEndpointSubnetId
  }
}

// ========================================
// Deploy Storage Account Module
// ========================================
module storageModule 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    replicationType: storageReplicationType
    sku: storageSku
    accessTier: storageAccessTier
    subnetId: subnetsModule.outputs.privateEndpointSubnetId
    enablePrivateEndpoint: storageEnablePrivateEndpoint
    containerAppSubnetId: subnetsModule.outputs.containerAppSubnetId
  }
}

// ========================================
// Outputs
// ========================================
output managedIdentityId string = managedIdentity.id
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityClientId string = managedIdentity.properties.clientId

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

output acrId string = acrModule.outputs.acrId
output acrLoginServer string = acrModule.outputs.acrLoginServer
output acrName string = acrModule.outputs.acrName

output postgresClusterName string = postgresModule.outputs.clusterName
output postgresClusterEndpoint string = postgresModule.outputs.clusterEndpoint
output postgresClusterResourceId string = postgresModule.outputs.clusterResourceId

output keyVaultId string = keyVaultModule.outputs.keyVaultId
output keyVaultName string = keyVaultModule.outputs.keyVaultName

output storageAccountId string = storageModule.outputs.storageAccountId
output storageAccountName string = storageModule.outputs.storageAccountName
output blobEndpoint string = storageModule.outputs.blobEndpoint

output containerEnvId string = containerAppEnvModule.outputs.containerEnvId
output containerEnvName string = containerAppEnvModule.outputs.containerEnvName
