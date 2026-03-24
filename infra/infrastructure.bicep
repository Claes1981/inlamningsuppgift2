@description('Resource group location')
param location string = 'denmarkeast'

@description('Virtual network name')
param vnetName string = 'DemoVNet'

@description('Virtual network address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet name')
param subnetName string = 'default'

@description('Subnet address prefix')
param subnetPrefix string = '10.0.0.0/24'

@description('Network security group name')
param nsgName string = 'DemoNSG'

@description('Application security group name for reverse proxy')
param reverseProxyAsgName string = 'ReverseProxyASG'

@description('Application security group name for bastion host')
param bastionHostAsgName string = 'BastionHostASG'

@description('VM size for all virtual machines')
param vmSize string = 'Standard_B1s'

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('Admin public SSH key for VMs')
@secure()
param adminPublicKey string

@description('Web server VM name')
param webServerName string = 'WebServer'

@description('Reverse proxy VM name')
param reverseProxyName string = 'ReverseProxy'

@description('Bastion host VM name')
param bastionHostName string = 'BastionHost'

@description('Cloud-init configuration for web server (base64 encoded)')
param webServerCloudInit string

@description('Cloud-init configuration for reverse proxy (base64 encoded)')
param reverseProxyCloudInit string

@description('Cloud-init configuration for bastion host (base64 encoded)')
param bastionHostCloudInit string = ''

@description('The name of the Cosmos DB account. Must be globally unique.')
param accountName string = 'claestodoappdbaccount'

@description('The name of the MongoDB database.')
param databaseName string = 'TodoAppDb'

@description('The name of the MongoDB collection.')
param collectionName string = 'todos'

@description('The shard key for the collection.')
param shardKey string = 'category'

// =============================================================================
// VARIABLES - DRY Principle
// =============================================================================

var ubuntuImage = {
  publisher: 'Canonical'
  offer: 'ubuntu-24_04-lts'
  sku: 'server'
  version: 'latest'
}

var sshConfig = {
  publicKeys: [
    {
      path: '/home/${adminUsername}/.ssh/authorized_keys'
      keyData: adminPublicKey
    }
  ]
}

var linuxConfig = {
  disablePasswordAuthentication: true
  ssh: sshConfig
}

var osDiskConfig = {
  createOption: 'FromImage'
  managedDisk: {
    storageAccountType: 'Standard_LRS'
  }
}

var publicIpSku = {
  name: 'Standard'
}

var publicIpProperties = {
  publicIPAllocationMethod: 'Static'
}

// Resource tags for organization and cost tracking
var commonTags = {
  project: 'TodoApp'
  environment: 'Demo'
  managedBy: 'Bicep'
  createdBy: 'Infrastructure-as-Code'
}

// =============================================================================
// APPLICATION SECURITY GROUPS
// =============================================================================

resource reverseProxyAsg 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: reverseProxyAsgName
  location: location
  tags: commonTags
}

resource bastionHostAsg 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: bastionHostAsgName
  location: location
  tags: commonTags
}

// =============================================================================
// VIRTUAL NETWORK
// =============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// =============================================================================
// NETWORK SECURITY GROUP
// =============================================================================

var nsgSecurityRules = [
  {
    name: 'AllowSSHToBastion'
    properties: {
      priority: 1000
      access: 'Allow'
      protocol: 'Tcp'
      direction: 'Inbound'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationPortRange: '22'
      destinationApplicationSecurityGroups: [
        {
          id: bastionHostAsg.id
        }
      ]
    }
  }
  {
    name: 'AllowHTTPToReverseProxy'
    properties: {
      priority: 2000
      access: 'Allow'
      protocol: 'Tcp'
      direction: 'Inbound'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationPortRange: '80'
      destinationApplicationSecurityGroups: [
        {
          id: reverseProxyAsg.id
        }
      ]
    }
  }
  {
    name: 'AllowCosmosDBAccess'
    properties: {
      priority: 2500
      access: 'Allow'
      protocol: 'Tcp'
      direction: 'Outbound'
      sourceAddressPrefix: vnetAddressPrefix
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '10255'
    }
  }
  {
    name: 'AllowInternalVNetTraffic'
    properties: {
      priority: 3000
      access: 'Allow'
      protocol: 'Tcp'
      direction: 'Inbound'
      sourceAddressPrefix: vnetAddressPrefix
      sourcePortRange: '*'
      destinationAddressPrefix: vnetAddressPrefix
      destinationPortRange: '22'
    }
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: nsgSecurityRules
  }
}

// Associate NSG with subnet
resource subnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// =============================================================================
// PUBLIC IP ADDRESSES
// =============================================================================

resource reverseProxyPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${reverseProxyName}PublicIP'
  location: location
  sku: publicIpSku
  properties: publicIpProperties
  tags: commonTags
}

resource bastionHostPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${bastionHostName}PublicIP'
  location: location
  sku: publicIpSku
  properties: publicIpProperties
  tags: commonTags
}

// =============================================================================
// NETWORK INTERFACES
// =============================================================================

resource webServerNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${webServerName}Nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
        }
      }
    ]
  }
  dependsOn: [
    subnetNsgAssociation
  ]
}

resource reverseProxyNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${reverseProxyName}Nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          publicIPAddress: {
            id: reverseProxyPublicIp.id
          }
          applicationSecurityGroups: [
            {
              id: reverseProxyAsg.id
            }
          ]
        }
      }
    ]
  }
}

resource bastionHostNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${bastionHostName}Nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          publicIPAddress: {
            id: bastionHostPublicIp.id
          }
          applicationSecurityGroups: [
            {
              id: bastionHostAsg.id
            }
          ]
        }
      }
    ]
  }
}

// =============================================================================
// VIRTUAL MACHINES
// =============================================================================

resource webServerVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: webServerName
  location: location
  tags: commonTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: replace(webServerName, '-', '')
      adminUsername: adminUsername
      customData: webServerCloudInit
      linuxConfiguration: linuxConfig
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: osDiskConfig
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: webServerNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource reverseProxyVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: reverseProxyName
  location: location
  tags: commonTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: replace(reverseProxyName, '-', '')
      adminUsername: adminUsername
      customData: reverseProxyCloudInit
      linuxConfiguration: linuxConfig
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: osDiskConfig
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: reverseProxyNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource bastionHostVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: bastionHostName
  location: location
  tags: commonTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: replace(bastionHostName, '-', '')
      adminUsername: adminUsername
      customData: bastionHostCloudInit
      linuxConfiguration: linuxConfig
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: osDiskConfig
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: bastionHostNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

// =============================================================================
// AZURE COSMOS DB WITH MONGODB API
// =============================================================================

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  kind: 'MongoDB'
  tags: commonTags
  properties: {
    databaseAccountOfferType: 'Standard'
    capabilities: [
      {
        name: 'EnableMongo'
      }
      {
        name: 'EnableServerless'
      }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    apiProperties: {
      serverVersion: '4.2'
    }
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource collection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2024-05-15' = {
  parent: database
  name: collectionName
  properties: {
    resource: {
      id: collectionName
      shardKey: {
        '${shardKey}': 'Hash'
      }
    }
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output reverseProxyPublicIp string = reverseProxyPublicIp.properties.ipAddress
output bastionHostPublicIp string = bastionHostPublicIp.properties.ipAddress
output webServerPrivateIp string = webServerNic.properties.ipConfigurations[0].properties.privateIPAddress
output reverseProxyPrivateIp string = reverseProxyNic.properties.ipConfigurations[0].properties.privateIPAddress
output bastionHostPrivateIp string = bastionHostNic.properties.ipConfigurations[0].properties.privateIPAddress

@description('The name of the deployed Cosmos DB account.')
output accountNameOutput string = cosmosAccount.name

@description('The endpoint for the Cosmos DB account.')
output cosmosDbEndpoint string = cosmosAccount.properties.documentEndpoint

output cosmosDbName string = cosmosAccount.name
output cosmosDatabaseName string = databaseName
output cosmosCollectionName string = collectionName
