targetScope = 'resourceGroup'

param prefix string
param location string
param tags object
param repoConfig object
param isDev bool

var gitConfig = union(repoConfig,  { rootFolder: 'adf' } )

resource purview 'Microsoft.Purview/accounts@2021-07-01' existing = {
  name: '${prefix}-pur'
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: '${prefix}-vnet'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'internal'
  parent: vnet
}

resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: '${prefix}-adf'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
     publicNetworkAccess: 'Disabled'
     purviewConfiguration: {
      purviewResourceId: purview.id
     }
     // TODO: Enable repoconfiguration to github
     // repoConfiguration: isDev ? gitConfig : null
  }
  tags: tags
}

resource dataFactoryEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${prefix}-adf-pe'
  location: location
  properties: {
    subnet: subnet
    privateLinkServiceConnections: [
      adf
    ]
  }
  tags: tags
}
