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

@description('Reverse proxy application security group name')
param reverseProxyAsgName string = 'ReverseProxyASG'

@description('Bastion host application security group name')
param bastionHostAsgName string = 'BastionHostASG'

@description('VM size')
param vmSize string = 'Standard_B1ls'

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

@description('Cloud-init configuration for web server (YAML format, base64 encoded by provisioning script)')
param webServerCloudInit string

@description('Cloud-init configuration for reverse proxy (YAML format, base64 encoded by provisioning script)')
param reverseProxyCloudInit string

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
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
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
        name: 'AllowHTTP'
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
        name: 'AllowInternalSSH'
        properties: {
          priority: 3000
          access: 'Allow'
          protocol: 'Tcp'
          direction: 'Inbound'
          sourceAddressPrefix: '10.0.0.0/16'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.0.0.0/16'
          destinationPortRange: '22'
        }
      }
    ]
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
  dependsOn: [
    nsg
  ]
}

// Reverse Proxy Public IP
resource reverseProxyPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${reverseProxyName}PublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Bastion Host Public IP
resource bastionHostPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${bastionHostName}PublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
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
  dependsOn: [
    subnetNsgAssociation
    reverseProxyPublicIp
  ]
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
  dependsOn: [
    subnetNsgAssociation
    bastionHostPublicIp
  ]
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
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
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
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
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
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
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
