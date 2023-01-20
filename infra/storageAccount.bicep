targetScope = 'resourceGroup'

param prefix string
param location string
param tags object
param ipExcemptions array
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param sku string = 'Standard_LRS'
@allowed([
  'BlobStorage'
  'BLockBlobStorage'
  'File'
  'Storage'
  'StorageV2'
])
param kind string = 'StorageV2'
@allowed([
  'Cool'
  'Hot'
  'Premium'
])
param defaultAccessTier string = 'Cool'
param containers array = [
  'raw'
  'structured'
  'curated'
  'drop'
  'gdpr'
  'opendata'
  'synapse'
]
param groupIds array = [
  'blob'
  'table'
  'queue'
  'file'
  'web'
  'dfs'
]
param managementPolicy object = {
  toCool: 30
  toCold: 365
  toArchive: 3 * 365
  toDelete: 7 * 356
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: '${prefix}-vnet'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'internal'
  parent: vnet
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: '${prefix}-kv'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: '${replace(prefix, '-', '')}sa'
  location: location
  sku: {
    name: sku
  }
  kind: kind
  identity: {
    type: 'SystemAssigned'
  }
  
  properties: {
    accessTier: defaultAccessTier
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowedCopyScope: 'PrivateLink'
    allowSharedKeyAccess: true
    isHnsEnabled: true
    keyPolicy: {
      keyExpirationPeriodInDays: 1
    }
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [for ip in ipExcemptions: {
        value: '${ip.address}'
        action: 'Allow'
      }]
      virtualNetworkRules: [
        {
          id: subnet.id
          state: 'Succeeded'
        }
      ]
    }
  }
  tags: tags
}

resource archivingRules 'Microsoft.Storage/storageAccounts/managementPolicies@2022-09-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    policy: {
      rules: [
        {
          name: 'lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterCreationGreaterThan: managementPolicy.toCool
                }
                tierToCold: {
                  daysAfterCreationGreaterThan: managementPolicy.toCold
                }
                tierToArchive: {
                  daysAfterCreationGreaterThan: managementPolicy.toArchive
                }
                delete: {
                  daysAfterCreationGreaterThan: managementPolicy.toDelete
                }
              }
              snapshot: {
                tierToCool: {
                  daysAfterCreationGreaterThan: managementPolicy.toCool
                }
                tierToCold: {
                  daysAfterCreationGreaterThan: managementPolicy.toCold
                }
                tierToArchive: {
                  daysAfterCreationGreaterThan: managementPolicy.toArchive
                }
                delete: {
                  daysAfterCreationGreaterThan: managementPolicy.toDelete
                }
              }
              version: {
                tierToCool: {
                  daysAfterCreationGreaterThan: managementPolicy.toCool
                }
                tierToCold: {
                  daysAfterCreationGreaterThan: managementPolicy.toCold
                }
                tierToArchive: {
                  daysAfterCreationGreaterThan: managementPolicy.toArchive
                }
                delete: {
                  daysAfterCreationGreaterThan: managementPolicy.toDelete
                }
              }
            }
          }
          type: 'Lifecycle'
          enabled: true
        }
      ]
    }
  }
}

resource storageAccountEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${replace(prefix, '-', '')}sa-pe'
  location: location
  properties: {
    subnet: subnet
    privateLinkServiceConnections: [
      storageAccount
    ]
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource storageContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for container in containers: {
  name: container
  parent: blobService
}]


resource primaryStorageKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'primary-storage-key'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
    value: storageAccount.listKeys().keys[0].value
  }
}

resource secondaryStorageKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'secondary-storage-key'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
    value: storageAccount.listKeys().keys[1].value
  }
}
