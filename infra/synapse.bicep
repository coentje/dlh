targetScope = 'resourceGroup'

param prefix string
param location string
param tags object
param repoConfig object
param isDev bool

var gitConfig = isDev ? null : union(repoConfig, { rootFolder: '/synapse' } )

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: '${prefix}-vnet'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'internal'
  parent: vnet
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: '${replace(prefix,'-','')}sa'
}

resource purview 'Microsoft.Purview/accounts@2021-07-01' existing = {
  name: '${prefix}-pur'
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: '${prefix}-kv'
}

resource passwordGenerator 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'password-generate'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '3.0' 
    retentionInterval: 'P1D'
    scriptContent: loadTextContent('../scripts/generatePassword.ps1')
  }
}

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: '${prefix}-syn-ws'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    azureADOnlyAuthentication: true
    defaultDataLakeStorage: {
      resourceId: storageAccount.id
      filesystem: 'synapse'
      accountUrl: storageAccount.properties.primaryEndpoints.dfs
    }
    purviewConfiguration: {
      purviewResourceId: purview.id
    }
    managedResourceGroupName: '${prefix}-pur-mngd'
    publicNetworkAccess: 'Enabled'
    // workspaceRepositoryConfiguration: repoConfig == null ? null : gitConfig
    trustedServiceBypassEnabled: true
    sqlAdministratorLogin: 'syn-sql-sa'
    sqlAdministratorLoginPassword: passwordGenerator.properties.outputs.password
  }
  tags: tags
}

resource synSaPwd 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'syn-sql-sa-pwd'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    contentType: 'plain/text'
    value: passwordGenerator.properties.outputs.password
  }
}
resource purviewEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${prefix}-syn-pe'
  location: location
  properties: {
    subnet: subnet
    privateLinkServiceConnections: [
      synapse
    ]
  }
  tags: tags
}
