#!/usr/bin/env bash

az group create --name DemoRG --location northeurope

az network vnet create \
  --resource-group DemoRG \
  --name DemoVNet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name default \
  --subnet-prefix 10.0.0.0/24

az network asg create \
  --resource-group DemoRG \
  --name ReverseProxyASG

az network asg create \
  --resource-group DemoRG \
  --name BastionHostASG

az network vnet list --resource-group DemoRG

az network nsg create \
  --resource-group DemoRG \
  --name DemoNSG

az network nsg rule create \
  --resource-group DemoRG \
  --nsg-name DemoNSG \
  --name AllowSSH \
  --priority 1000 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes Internet \
  --source-port-ranges "*" \
  --destination-asg BastionHostASG \
  --destination-port-ranges 22

az network nsg rule create \
  --resource-group DemoRG \
  --nsg-name DemoNSG \
  --name AllowHTTP \
  --priority 2000 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes Internet \
  --source-port-ranges "*" \
  --destination-asg ReverseProxyASG \
  --destination-port-ranges 80

az network vnet subnet update \
  --resource-group DemoRG \
  --vnet-name DemoVNet \
  --name default \
  --network-security-group DemoNSG

az network nsg rule list --resource-group DemoRG --nsg-name DemoNSG --output table

az vm create \
  --resource-group DemoRG \
  --name WebServer \
  --image Ubuntu2204 \
  --size Standard_F1als_v7 \
  --admin-username azureuser \
  --vnet-name DemoVNet \
  --subnet default \
  --nsg "" \
  --public-ip-address "" \
  --generate-ssh-keys \
  --custom-data @web_server_config.yaml

az vm create \
  --resource-group DemoRG \
  --name ReverseProxy \
  --image Ubuntu2204 \
  --size Standard_F1als_v7 \
  --admin-username azureuser \
  --vnet-name DemoVNet \
  --subnet default \
  --nsg "" \
  --generate-ssh-keys \
  --custom-data @reverse_proxy_config.yaml

az vm create \
  --resource-group DemoRG \
  --name BastionHost \
  --image Ubuntu2204 \
  --size Standard_F1als_v7 \
  --admin-username azureuser \
  --vnet-name DemoVNet \
  --subnet default \
  --nsg "" \
  --generate-ssh-keys

az vm list --resource-group DemoRG --output table

REVERSE_PROXY_NIC_ID=$(az vm show \
  --resource-group DemoRG \
  --name ReverseProxy \
  --query 'networkProfile.networkInterfaces[0].id' \
  --output tsv)

REVERSE_PROXY_NIC_NAME=$(basename $REVERSE_PROXY_NIC_ID)

REVERSE_PROXY_NIC_IP_CONFIG=$(az network nic show \
  --resource-group DemoRG \
  --name $REVERSE_PROXY_NIC_NAME \
  --query 'ipConfigurations[0].name' \
  --output tsv)

az network nic ip-config update \
  --resource-group DemoRG \
  --nic-name $REVERSE_PROXY_NIC_NAME \
  --name $REVERSE_PROXY_NIC_IP_CONFIG \
  --application-security-groups ReverseProxyASG

BASTION_HOST_NIC_ID=$(az vm show \
  --resource-group DemoRG \
  --name BastionHost \
  --query 'networkProfile.networkInterfaces[0].id' \
  --output tsv)

BASTION_HOST_NIC_NAME=$(basename $BASTION_HOST_NIC_ID)

BASTION_HOST_NIC_IP_CONFIG=$(az network nic show \
  --resource-group DemoRG \
  --name $BASTION_HOST_NIC_NAME \
  --query 'ipConfigurations[0].name' \
  --output tsv)

az network nic ip-config update \
  --resource-group DemoRG \
  --nic-name $BASTION_HOST_NIC_NAME \
  --name $BASTION_HOST_NIC_IP_CONFIG \
  --application-security-groups BastionHostASG

az network nic show --resource-group DemoRG --name $REVERSE_PROXY_NIC_NAME --query 'ipConfigurations[0].applicationSecurityGroups'

REVERSE_PROXY_IP=$(az vm show \
  --resource-group DemoRG \
  --name ReverseProxy \
  --show-details \
  --query 'publicIps' \
  --output tsv)

echo "Reverse Proxy IP: $REVERSE_PROXY_IP"

curl http://$REVERSE_PROXY_IP

BASTION_IP=$(az vm show \
  --resource-group DemoRG \
  --name BastionHost \
  --show-details \
  --query 'publicIps' \
  --output tsv)

echo "Bastion Host IP: $BASTION_IP"

