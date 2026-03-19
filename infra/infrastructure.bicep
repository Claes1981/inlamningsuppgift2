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

// Variables - DRY principle: define common configurations once
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

// Application Security Groups
resource reverseProxyAsg 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: reverseProxyAsgName
  location: location
  tags: {
    name: reverseProxyAsgName
  }
}

resource bastionHostAsg 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: bastionHostAsgName
  location: location
  tags: {
    name: bastionHostAsgName
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
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

// Network Security Group
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

// Reverse Proxy Public IP
resource reverseProxyPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${reverseProxyName}PublicIP'
  location: location
  sku: publicIpSku
  properties: publicIpProperties
}

// Bastion Host Public IP
resource bastionHostPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${bastionHostName}PublicIP'
  location: location
  sku: publicIpSku
  properties: publicIpProperties
}

// Web Server NIC (no public IP)
resource webServerNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${webServerName}Nic'
  location: location
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

// Reverse Proxy NIC with ASG
resource reverseProxyNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${reverseProxyName}Nic'
  location: location
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

// Bastion Host NIC with ASG
resource bastionHostNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${bastionHostName}Nic'
  location: location
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

// Web Server VM
resource webServerVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: webServerName
  location: location
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

// Reverse Proxy VM
resource reverseProxyVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: reverseProxyName
  location: location
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

// Bastion Host VM
resource bastionHostVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: bastionHostName
  location: location
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

// Outputs
output reverseProxyPublicIp string = reverseProxyPublicIp.properties.ipAddress
output bastionHostPublicIp string = bastionHostPublicIp.properties.ipAddress
output webServerPrivateIp string = webServerNic.properties.ipConfigurations[0].properties.privateIPAddress
output reverseProxyPrivateIp string = reverseProxyNic.properties.ipConfigurations[0].properties.privateIPAddress
output bastionHostPrivateIp string = bastionHostNic.properties.ipConfigurations[0].properties.privateIPAddress
