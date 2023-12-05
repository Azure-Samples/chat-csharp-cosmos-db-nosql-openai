metadata description = 'Create web application resources.'

param envName string
param appName string
param serviceTag string
param location string = resourceGroup().location
param tags object = {}

@description('Endpoint for Azure Cosmos DB for NoSQL account.')
param databaseAccountEndpoint string

type managedIdentity = {
  resourceId: string
  clientId: string
}

@description('Unique identifier for user-assigned managed identity.')
param userAssignedManagedIdentity managedIdentity

module containerAppsEnvironment '../core/host/container-apps/environments/managed.bicep' = {
  name: 'container-apps-env'
  params: {
    name: envName
    location: location
    tags: tags
  }
}

module containerAppsApp '../core/host/container-apps/app.bicep' = {
  name: 'container-apps-app'
  params: {
    name: appName
    parentEnvironmentName: containerAppsEnvironment.outputs.name
    location: location
    tags: union(tags, {
        'azd-service-name': serviceTag
      })
    secrets: [
      {
        name: 'azure-cosmos-db-nosql-endpoint' // Create a uniquely-named secret
        value: databaseAccountEndpoint // NoSQL database account endpoint
      }
      {
        name: 'azure-managed-identity-client-id' // Create a uniquely-named secret
        value: userAssignedManagedIdentity.clientId // Client ID of user-assigned managed identity
      }
    ]
    environmentVariables: [
      {
        name: 'AZURE_COSMOS_DB_NOSQL_ENDPOINT' // Name of the environment variable referenced in the application
        secretRef: 'azure-cosmos-db-nosql-endpoint' // Reference to secret
      }
      {
        name: 'AZURE_MANAGED_IDENTITY_CLIENT_ID'
        secretRef: 'azure-managed-identity-client-id'
      }
    ]
    targetPort: 8080
    enableSystemAssignedManagedIdentity: false
    userAssignedManagedIdentityIds: [
      userAssignedManagedIdentity.resourceId
    ]
    containerImage: 'ghcr.io/azure-samples/cosmos-db-nosql-dotnet-quickstart:main' // Pre-built container image and tag from GitHub
  }
}

output endpoint string = containerAppsApp.outputs.endpoint
output envName string = containerAppsApp.outputs.name
