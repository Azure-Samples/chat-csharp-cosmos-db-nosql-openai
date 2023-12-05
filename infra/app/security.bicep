metadata description = 'Create role assignment and definition resources.'

param databaseAccountName string

@description('Id of the service principals to assign database and application roles.')
param appPrincipalId string = ''

@description('Id of the user principals to assign database and application roles.')
param userPrincipalId string = ''

resource database 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: databaseAccountName
}

module nosqlDefinition '../core/database/cosmos-db/nosql/role/definition.bicep' = {
  name: 'nosql-role-definition'
  params: {
    targetAccountName: database.name // Existing account
    definitionName: 'Write to Azure Cosmos DB for NoSQL data plane' // Custom role name
    permissionsDataActions: [
      'Microsoft.DocumentDB/databaseAccounts/readMetadata' // Read account metadata
      'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*' // Create items
      'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*' // Manage items
    ]
  }
}

module nosqlAppAssignment '../core/database/cosmos-db/nosql/role/assignment.bicep' = if (!empty(appPrincipalId)) {
  name: 'nosql-role-assignment-app'
  params: {
    targetAccountName: database.name // Existing account
    roleDefinitionId: nosqlDefinition.outputs.id // New role definition
    principalId: appPrincipalId // Principal to assign role
  }
}

module nosqlUserAssignment '../core/database/cosmos-db/nosql/role/assignment.bicep' = if (!empty(userPrincipalId)) {
  name: 'nosql-role-assignment-user'
  params: {
    targetAccountName: database.name // Existing account
    roleDefinitionId: nosqlDefinition.outputs.id // New role definition
    principalId: userPrincipalId ?? '' // Principal to assign role
  }
}

module registryUserAssignment '../core/security/role/assignment.bicep' = if (!empty(userPrincipalId)) {
  name: 'container-registry-role-assignment-push-user'
  params: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec') // AcrPush built-in role
    principalId: userPrincipalId // Principal to assign role
    principalType: 'User' // Current deployment user
  }
}

output roleDefinitions object = {
  nosql: nosqlDefinition.outputs.id
}

output roleAssignments array = union(
  !empty(appPrincipalId) ? [ nosqlAppAssignment.outputs.id ] : [],
  !empty(userPrincipalId) ? [ nosqlUserAssignment.outputs.id, registryUserAssignment.outputs.id ] : []
)
