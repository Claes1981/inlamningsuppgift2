#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_NAME="Azure Infrastructure Provisioning"
readonly RESOURCE_GROUP="DemoRG"
readonly LOCATION="denmarkeast"

readonly VNET_NAME="DemoVNet"
readonly VNET_ADDRESS_PREFIX="10.0.0.0/16"
readonly SUBNET_NAME="default"
readonly SUBNET_PREFIX="10.0.0.0/24"

readonly NSG_NAME="DemoNSG"

readonly REVERSE_PROXY_ASG="ReverseProxyASG"
readonly BASTION_HOST_ASG="BastionHostASG"

readonly VM_IMAGE="Ubuntu2204"
readonly VM_SIZE="Standard_B1ls"
readonly ADMIN_USERNAME="azureuser"

readonly WEB_SERVER_NAME="WebServer"
readonly REVERSE_PROXY_NAME="ReverseProxy"
readonly BASTION_HOST_NAME="BastionHost"

readonly WEB_SERVER_CONFIG="web_server_config.yaml"
readonly REVERSE_PROXY_CONFIG="reverse_proxy_config.yaml"

log() {
  echo "[INFO] $1"
}

log_section() {
  echo ""
  echo "========================================"
  echo "[SECTION] $1"
  echo "========================================"
  echo ""
}

create_resource_group() {
  log "Creating resource group: ${RESOURCE_GROUP}"

  az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}"
}

create_virtual_network() {
  log "Creating virtual network: ${VNET_NAME}"

  az network vnet create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${VNET_NAME}" \
    --address-prefix "${VNET_ADDRESS_PREFIX}" \
    --subnet-name "${SUBNET_NAME}" \
    --subnet-prefix "${SUBNET_PREFIX}"

  log "Listing virtual networks in resource group"
  az network vnet list \
    --resource-group "${RESOURCE_GROUP}"
}

create_application_security_group() {
  local asg_name="$1"

  log "Creating application security group: ${asg_name}"

  az network asg create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${asg_name}"
}

create_application_security_groups() {
  log_section "Creating Application Security Groups"

  create_application_security_group "${REVERSE_PROXY_ASG}"
  create_application_security_group "${BASTION_HOST_ASG}"
}

create_network_security_group() {
  log "Creating network security group: ${NSG_NAME}"

  az network nsg create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${NSG_NAME}"
}

create_nsg_rule() {
  local rule_name="$1"
  local priority="$2"
  local protocol="$3"
  local destination_asg="$4"
  local destination_port="$5"

  log "Creating NSG rule: ${rule_name} (priority: ${priority})"

  az network nsg rule create \
    --resource-group "${RESOURCE_GROUP}" \
    --nsg-name "${NSG_NAME}" \
    --name "${rule_name}" \
    --priority "${priority}" \
    --access Allow \
    --protocol "${protocol}" \
    --direction Inbound \
    --source-address-prefixes Internet \
    --source-port-ranges "*" \
    --destination-asg "${destination_asg}" \
    --destination-port-ranges "${destination_port}"
}

configure_network_security_group() {
  log_section "Configuring Network Security Group"

  create_network_security_group

  create_nsg_rule "AllowSSH" 1000 Tcp "${BASTION_HOST_ASG}" 22
  create_nsg_rule "AllowHTTP" 2000 Tcp "${REVERSE_PROXY_ASG}" 80

  log "Associating NSG with subnet"

  az network vnet subnet update \
    --resource-group "${RESOURCE_GROUP}" \
    --vnet-name "${VNET_NAME}" \
    --name "${SUBNET_NAME}" \
    --network-security-group "${NSG_NAME}"

  log "Listing NSG rules"
  az network nsg rule list \
    --resource-group "${RESOURCE_GROUP}" \
    --nsg-name "${NSG_NAME}" \
    --output table
}

create_virtual_machine() {
  local vm_name="$1"
  local custom_data="${2:-}"

  log "Creating virtual machine: ${vm_name}"

  local vm_args=(
    --resource-group "${RESOURCE_GROUP}"
    --name "${vm_name}"
    --image "${VM_IMAGE}"
    --size "${VM_SIZE}"
    --admin-username "${ADMIN_USERNAME}"
    --vnet-name "${VNET_NAME}"
    --subnet "${SUBNET_NAME}"
    --nsg ""
    --public-ip-address ""
    --generate-ssh-keys
  )

  if [[ -n "${custom_data}" ]]; then
    vm_args+=(--custom-data "@${custom_data}")
  fi

  az vm create "${vm_args[@]}"
}

create_virtual_machines() {
  log_section "Creating Virtual Machines"

  create_virtual_machine "${WEB_SERVER_NAME}" "${WEB_SERVER_CONFIG}"
  create_virtual_machine "${REVERSE_PROXY_NAME}" "${REVERSE_PROXY_CONFIG}"
  create_virtual_machine "${BASTION_HOST_NAME}"
}

get_vm_nic_name() {
  local vm_name="$1"

  az vm show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${vm_name}" \
    --query 'networkProfile.networkInterfaces[0].id' \
    --output tsv | xargs basename
}

assign_asg_to_vm_nic() {
  local vm_name="$1"
  local asg_name="$2"

  log "Assigning ASG '${asg_name}' to VM '${vm_name}' NIC"

  local nic_name
  nic_name=$(get_vm_nic_name "${vm_name}")

  local ip_config_name
  ip_config_name=$(az network nic show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${nic_name}" \
    --query 'ipConfigurations[0].name' \
    --output tsv)

  az network nic ip-config update \
    --resource-group "${RESOURCE_GROUP}" \
    --nic-name "${nic_name}" \
    --name "${ip_config_name}" \
    --application-security-groups "${asg_name}"
}

assign_application_security_groups() {
  log_section "Assigning Application Security Groups to VMs"

  assign_asg_to_vm_nic "${REVERSE_PROXY_NAME}" "${REVERSE_PROXY_ASG}"
  assign_asg_to_vm_nic "${BASTION_HOST_NAME}" "${BASTION_HOST_ASG}"

  log "Verifying ASG assignment for reverse proxy"
  local nic_name
  nic_name=$(get_vm_nic_name "${REVERSE_PROXY_NAME}")

  az network nic show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${nic_name}" \
    --query 'ipConfigurations[0].applicationSecurityGroups'
}

get_vm_public_ip() {
  local vm_name="$1"

  az vm show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${vm_name}" \
    --show-details \
    --query 'publicIps' \
    --output tsv
}

display_vm_list() {
  log_section "Virtual Machine List"

  az vm list \
    --resource-group "${RESOURCE_GROUP}" \
    --output table
}

display_connection_info() {
  log_section "Connection Information"

  local reverse_proxy_ip
  reverse_proxy_ip=$(get_vm_public_ip "${REVERSE_PROXY_NAME}")
  echo "Reverse Proxy IP: ${reverse_proxy_ip}"

  local bastion_host_ip
  bastion_host_ip=$(get_vm_public_ip "${BASTION_HOST_NAME}")
  echo "Bastion Host IP: ${bastion_host_ip}"
}

test_reverse_proxy() {
  log_section "Testing Reverse Proxy"

  local reverse_proxy_ip
  reverse_proxy_ip=$(get_vm_public_ip "${REVERSE_PROXY_NAME}")

  if [[ -n "${reverse_proxy_ip}" ]]; then
    log "Testing HTTP connection to reverse proxy"
    curl --fail --silent --max-time 10 "http://${reverse_proxy_ip}" || \
      log "Warning: Reverse proxy not responding yet"
  else
    log "Warning: Reverse proxy IP not available"
  fi
}

main() {
  log_section "${SCRIPT_NAME}"

  create_resource_group
  create_virtual_network
  create_application_security_groups
  configure_network_security_group
  create_virtual_machines
  assign_application_security_groups
  display_vm_list
  display_connection_info
  test_reverse_proxy

  log_section "Provisioning Complete"
}

main "$@"
