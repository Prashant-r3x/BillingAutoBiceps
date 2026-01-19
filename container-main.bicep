targetScope = 'resourceGroup'

// General parameters
@description('Container App Environment Resource ID')
param containerAppEnvId string

@description('Azure Container Registry login server')
param acrLoginServer string

@description('Existing User-Assigned Managed Identity Resource ID')
param userAssignedIdentityId string

// B2C Billing Frontend parameters
@description('Image name and tag for b2c-billing-frontend')
param frontendImageName string

@description('Frontend CPU cores')
param frontendCpu int

@description('Frontend memory')
param frontendMemory string

@description('Frontend port')
param frontendPort int

// B2C Billing Backend parameters
@description('Image name and tag for b2c-billing-backend')
param backendImageName string

@description('Backend CPU cores')
param backendCpu int

@description('Backend memory')
param backendMemory string

@description('Backend port')
param backendPort int

// Deploy B2C Billing Frontend
module b2cBillingFrontend 'b2c-billing-frontend.bicep' = {
  name: 'b2c-billing-frontend'
  params: {
    location: resourceGroup().location
    containerAppName: 'b2c-billing-frontend'
    containerAppEnvId: containerAppEnvId
    acrLoginServer: acrLoginServer
    imageName: frontendImageName
    cpu: frontendCpu
    memory: frontendMemory
    containerPort: frontendPort
    identityType: 'UserAssigned'
    userAssignedIdentityId: userAssignedIdentityId
    backendApiUrl: b2cBillingBackend.outputs.containerAppUrl
  }
}

// Deploy B2C Billing Backend
module b2cBillingBackend 'b2c-billing-backend.bicep' = {
  name: 'b2c-billing-backend'
  params: {
    location: resourceGroup().location
    containerAppName: 'b2c-billing-backend'
    containerAppEnvId: containerAppEnvId
    acrLoginServer: acrLoginServer
    imageName: backendImageName
    cpu: backendCpu
    memory: backendMemory
    containerPort: backendPort
    identityType: 'UserAssigned'
    userAssignedIdentityId: userAssignedIdentityId
  }
}

// Outputs
output frontendContainerAppId string = b2cBillingFrontend.outputs.containerAppId
output frontendContainerAppUrl string = b2cBillingFrontend.outputs.containerAppUrl
output backendContainerAppId string = b2cBillingBackend.outputs.containerAppId
output backendContainerAppUrl string = b2cBillingBackend.outputs.containerAppUrl
