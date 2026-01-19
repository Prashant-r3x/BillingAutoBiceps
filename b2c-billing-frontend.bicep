targetScope = 'resourceGroup'

@description('Location for Container App deployment')
param location string

@description('Container App name')
param containerAppName string

@description('Container App Environment Resource ID')
param containerAppEnvId string

@description('Azure Container Registry login server')
param acrLoginServer string

@description('Image name and tag')
param imageName string

@description('CPU cores')
param cpu int

@description('Memory in GiB')
param memory string

@description('Port exposed by the container')
param containerPort int

@description('Identity type (SystemAssigned or UserAssigned)')
param identityType string

@description('User Assigned Managed Identity Resource ID')
param userAssignedIdentityId string

@description('Subdomain prefix for custom domain (e.g., billing-frontend for billing-frontend.lyzr.dev.ai.wtwco.com)')
param subdomainPrefix string = ''

@description('Custom domain base (e.g., lyzr.dev.ai.wtwco.com)')
param customDomainBase string = ''

@description('Certificate ID from Container App Environment (leave empty to disable HTTPS)')
param certificateId string = ''

@description('Backend API URL')
param backendApiUrl string = ''

// Reference the User-Assigned Managed Identity to get its client ID
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: last(split(userAssignedIdentityId, '/'))
}

// Build the identity block dynamically
var identityBlock = identityType == 'UserAssigned'
  ? {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${userAssignedIdentityId}': {}
      }
    }
  : {
      type: 'SystemAssigned'
    }

// Create the container app using the passed identity
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: identityBlock
  properties: {
    managedEnvironmentId: containerAppEnvId
    configuration: {
      ingress: {
        external: true
        targetPort: containerPort
        customDomains: (subdomainPrefix != '' && customDomainBase != '') ? [
          {
            name: '${subdomainPrefix}.${customDomainBase}'
            bindingType: certificateId != '' ? 'SniEnabled' : 'Disabled'
            certificateId: certificateId != '' ? certificateId : null
          }
        ] : []
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityType == 'SystemAssigned' ? 'System' : userAssignedIdentityId
        }
      ]
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: '${acrLoginServer}/${imageName}'
          resources: {
            cpu: cpu
            memory: memory
          }
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: userAssignedIdentity.properties.clientId
            }
            {
              name: 'BACKEND_API_URL'
              value: backendApiUrl
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
      }
    }
  }
}

// Outputs
output containerAppId string = containerApp.id
output containerAppUrl string = containerApp.properties.configuration.ingress.fqdn
