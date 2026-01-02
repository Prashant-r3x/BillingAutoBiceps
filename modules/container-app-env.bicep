targetScope = 'resourceGroup'

@description('Location for Container App Environment')
param location string = resourceGroup().location

@description('Name of the Container App Environment')
param containerAppEnvName string

@description('Subnet ID for Container App Environment')
param appSubnetId string

@description('Workload profile name')
param workloadProfileName string = 'Consumption'

@description('Workload profile type (Consumption, Dedicated, etc)')
param workloadProfileType string = 'Consumption'

@description('Use internal-only environment')
param internal bool = true

@description('User Assigned Managed Identity Resource ID')
param managedIdentityId string

@description('Log Analytics Workspace ID for Container App Environment logs')
param logAnalyticsWorkspaceId string

// Reference existing managed identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(managedIdentityId, '/'))
}

// Reference existing Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

// Container Apps Environment
resource containerEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: appSubnetId
      internal: internal
    }
    workloadProfiles: [
      {
        name: workloadProfileName
        workloadProfileType: workloadProfileType
      }
    ]
  }
}

output containerEnvId string = containerEnv.id
output containerEnvPrincipalId string = managedIdentity.properties.principalId
output containerEnvName string = containerEnv.name
