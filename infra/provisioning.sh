#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="Azure Infrastructure Provisioning"
readonly RESOURCE_GROUP="TodoAppResourceGroup"
readonly LOCATION="denmarkeast"
readonly BICEP_FILE="infrastructure.bicep"

readonly VM_SIZE="Standard_B1ls"
readonly ADMIN_USERNAME="azureuser"
readonly SSH_KEY_FILE="${HOME}/.ssh/id_rsa.pub"
readonly SSH_KEY_TYPE="rsa"
readonly SSH_KEY_BITS=4096

readonly WEB_SERVER_NAME="WebServer"
readonly REVERSE_PROXY_NAME="ReverseProxy"
readonly BASTION_HOST_NAME="BastionHost"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLOUD_INIT_WEBSERVER="${SCRIPT_DIR}/cloud-init_webserver.sh"
readonly CLOUD_INIT_REVERSEPROXY="${SCRIPT_DIR}/cloud-init_reverseproxy.sh"
readonly CLOUD_INIT_BASTION="${SCRIPT_DIR}/cloud-init_bastion.sh"

readonly CLOUD_INIT_FILES=("${CLOUD_INIT_WEBSERVER}" "${CLOUD_INIT_REVERSEPROXY}" "${CLOUD_INIT_BASTION}")

readonly MAX_RETRY_ATTEMPTS=60
readonly RETRY_DELAY_SECONDS=5
readonly COSMOS_DB_RETRY_DELAY_SECONDS=10
readonly PROVISIONING_OUTPUTS_FILE="/tmp/provisioning_outputs.json"

# GitHub token (set by prompt_github_token or environment variable)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# MongoDB connection string (set by prompt_mongodb_connection_string)
MONGODB_CONNECTION_STRING=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

log_warning() {
  echo "[WARNING] $1"
}

log_section() {
  echo ""
  echo "========================================"
  echo "[SECTION] $1"
  echo "========================================"
  echo ""
}

cleanup() {
  local exit_code=$?
  if [[ ${exit_code} -ne 0 ]]; then
    log_error "Script failed with exit code: ${exit_code}"
  fi
}

trap cleanup EXIT

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_prerequisites() {
  log "Validating prerequisites..."

  local prerequisites=("az" "base64" "ssh-keygen")
  local missing=()

  for cmd in "${prerequisites[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
      missing+=("${cmd}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    return 1
  fi

  log "All prerequisites validated"
}

validate_bicep_file() {
  local bicep_path="${1}"

  log "Validating Bicep file: ${bicep_path}"

  if [[ ! -f "${bicep_path}" ]]; then
    log_error "Bicep file not found: ${bicep_path}"
    return 1
  fi

  if ! az bicep build --file "${bicep_path}" > /dev/null 2>&1; then
    log_error "Bicep file validation failed"
    return 1
  fi

  log "Bicep file validation successful"
}

validate_cloud_init_files() {
  log "Validating cloud-init files..."

  for file in "${CLOUD_INIT_FILES[@]}"; do
    if [[ ! -f "${file}" ]]; then
      log_error "Cloud-init file not found: ${file}"
      return 1
    fi

    if ! grep -q "^#cloud-config" "${file}"; then
      log_error "Invalid cloud-init format: ${file}"
      return 1
    fi
  done

  log "Cloud-init files validated"
}

# =============================================================================
# SSH KEY MANAGEMENT
# =============================================================================

ensure_ssh_directory() {
  if [[ ! -d "${HOME}/.ssh" ]]; then
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
  fi
}

generate_ssh_key() {
  local key_path="${HOME}/.ssh/id_rsa"

  log "Generating new SSH key pair..."
  ssh-keygen -t "${SSH_KEY_TYPE}" -b "${SSH_KEY_BITS}" -f "${key_path}" -N "" -q
  chmod 600 "${key_path}"
  chmod 644 "${key_path}.pub"
  log "SSH key pair generated"
}

ensure_ssh_key() {
  log_section "SSH Key Setup"
  ensure_ssh_directory

  if [[ -f "${SSH_KEY_FILE}" ]]; then
    log "Found existing SSH public key: ${SSH_KEY_FILE}"
  else
    generate_ssh_key
  fi
}

get_ssh_public_key() {
  tr -d '\r\n' < "${SSH_KEY_FILE}"
}

validate_ssh_key() {
  local ssh_key
  ssh_key=$(get_ssh_public_key)

  if [[ -z "${ssh_key}" ]]; then
    log_error "SSH public key is empty"
    return 1
  fi

  if [[ ${#ssh_key} -lt 100 ]]; then
    log_warning "SSH key length seems short: ${#ssh_key} characters"
  fi

  return 0
}

# =============================================================================
# AZURE RESOURCE MANAGEMENT
# =============================================================================

resource_group_exists() {
  local rg_name="$1"

  az group show \
    --name "${rg_name}" \
    --output tsv > /dev/null 2>&1
}

create_resource_group() {
  log "Creating resource group: ${RESOURCE_GROUP}"

  if resource_group_exists "${RESOURCE_GROUP}"; then
    log "Resource group already exists"
    return 0
  fi

  az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}"

  log "Resource group created"
}

wait_for_resource() {
  local resource_type="$1"
  local resource_name="$2"
  local query="$3"

  log "Waiting for ${resource_type} '${resource_name}' to be available..."

  local attempt=0

  while [[ ${attempt} -lt ${MAX_RETRY_ATTEMPTS} ]]; do
    attempt=$((attempt + 1))

    if az resource show \
      --resource-group "${RESOURCE_GROUP}" \
      --resource-type "${resource_type}" \
      --name "${resource_name}" \
      --query "${query}" \
      --output tsv > /dev/null 2>&1; then
      log "${resource_type} '${resource_name}' is ready"
      return 0
    fi

    log "Attempt ${attempt}/${MAX_RETRY_ATTEMPTS}: Resource not ready yet, waiting ${RETRY_DELAY_SECONDS}s..."
    sleep "${RETRY_DELAY_SECONDS}"
  done

  log_error "${resource_type} '${resource_name}' did not become available"
  return 1
}

# Wait for Cosmos DB to be ready
wait_for_cosmos_db() {
  local account_name="$1"
  
  log "Waiting for Cosmos DB '${account_name}' to be ready..."
  
  local attempt=0
  
  while [[ ${attempt} -lt ${MAX_RETRY_ATTEMPTS} ]]; do
    attempt=$((attempt + 1))
    
    local provisioning_state
    provisioning_state=$(az cosmosdb show \
      --name "${account_name}" \
      --resource-group "${RESOURCE_GROUP}" \
      --query 'provisioningState' \
      --output tsv 2>&1)
    
    # Check if command failed
    if [[ "${provisioning_state}" == *"ERROR"* || "${provisioning_state}" == *"error"* ]]; then
      log "Attempt ${attempt}/${MAX_RETRY_ATTEMPTS}: Error querying Cosmos DB, waiting ${COSMOS_DB_RETRY_DELAY_SECONDS}s..."
      sleep "${COSMOS_DB_RETRY_DELAY_SECONDS}"
      continue
    fi
    
    if [[ "${provisioning_state}" == "Succeeded" ]]; then
      log "Cosmos DB '${account_name}' is ready"
      return 0
    fi
    
    log "Attempt ${attempt}/${MAX_RETRY_ATTEMPTS}: Cosmos DB provisioning state: '${provisioning_state}', waiting ${COSMOS_DB_RETRY_DELAY_SECONDS}s..."
    sleep "${COSMOS_DB_RETRY_DELAY_SECONDS}"
  done
  
  log_error "Cosmos DB '${account_name}' did not become ready"
  return 1
}

# Generate MongoDB connection string from Cosmos DB
generate_mongodb_connection_string() {
  local account_name="$1"
  
  log "Generating MongoDB connection string for Cosmos DB '${account_name}'..."
  
  # Get the full connection string from Cosmos DB
  MONGODB_CONNECTION_STRING=$(az cosmosdb keys list \
    --name "${account_name}" \
    --resource-group "${RESOURCE_GROUP}" \
    --type connection-strings \
    --query 'connectionStrings[0].connectionString' \
    --output tsv 2>/dev/null)
  
  if [[ -z "${MONGODB_CONNECTION_STRING}" ]]; then
    log_error "Failed to retrieve Cosmos DB connection string"
    return 1
  fi
  
  log "MongoDB connection string generated successfully"
}

# =============================================================================
# PROVISIONING FUNCTIONS
# =============================================================================

prompt_github_token() {
  log_section "GitHub Actions Runner Configuration"
  
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    log "Using GITHUB_TOKEN from environment variable"
    log "Token received (not displayed for security)"
    return 0
  fi
  
  echo "Please enter your GitHub Actions PAT token for the runner configuration."
  echo "The token should have 'repo' and 'workflow' scopes."
  echo "Alternatively, set the GITHUB_TOKEN environment variable."
  echo ""
  read -rsp "Enter token: " GITHUB_TOKEN
  echo ""
  
  if [[ -z "${GITHUB_TOKEN}" ]]; then
    log_error "GitHub token cannot be empty"
    return 1
  fi
  
  log "Token received (not displayed for security)"
}

encode_cloud_init() {
  local cloud_init_file="$1"
  local token="$2"
  local mongo_connection_string="$3"
  
  local temp_file="${cloud_init_file}.tmp"
  cp "${cloud_init_file}" "${temp_file}"
  
  if [[ -n "${token}" ]]; then
    sed -i "s|{{GITHUB_TOKEN}}|${token}|g" "${temp_file}"
  fi
  
  if [[ -n "${mongo_connection_string}" ]]; then
    sed -i "s|{{MONGODB_CONNECTION_STRING}}|${mongo_connection_string}|g" "${temp_file}"
  fi
  
  base64 -w0 < "${temp_file}"
  rm -f "${temp_file}"
}

create_provisioning_parameters() {
  local ssh_key="$1"
  local github_token="$2"
  local output_file="$3"

  local web_server_cloud_init
  web_server_cloud_init=$(encode_cloud_init "${CLOUD_INIT_WEBSERVER}" "${github_token}" "")

  local reverse_proxy_cloud_init
  reverse_proxy_cloud_init=$(encode_cloud_init "${CLOUD_INIT_REVERSEPROXY}" "" "")

  local bastion_host_cloud_init
  bastion_host_cloud_init=$(encode_cloud_init "${CLOUD_INIT_BASTION}" "" "")

  cat > "${output_file}" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "${LOCATION}"
    },
    "adminPublicKey": {
      "value": "${ssh_key}"
    },
    "webServerCloudInit": {
      "value": "${web_server_cloud_init}"
    },
    "reverseProxyCloudInit": {
      "value": "${reverse_proxy_cloud_init}"
    },
    "bastionHostCloudInit": {
      "value": "${bastion_host_cloud_init}"
    }
  }
}
EOF
}

provision_infrastructure() {
  log_section "Provisioning Infrastructure with Bicep"

  local ssh_key
  ssh_key=$(get_ssh_public_key)

  if ! validate_ssh_key; then
    log_error "SSH key validation failed"
    return 1
  fi

  log "SSH key length: ${#ssh_key} characters"

  if ! prompt_github_token; then
    log_error "Failed to get GitHub token"
    return 1
  fi

  local params_file
  params_file=$(mktemp)
  trap 'rm -f "${params_file:-}"' RETURN

  create_provisioning_parameters "${ssh_key}" "${GITHUB_TOKEN}" "${params_file}"

  log "Provisioning Bicep template to resource group: ${RESOURCE_GROUP}"

  az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "${SCRIPT_DIR}/${BICEP_FILE}" \
    --parameters "@${params_file}" \
    --query 'properties.outputs' \
    --output json > "${PROVISIONING_OUTPUTS_FILE}"

  # Get Cosmos DB account name from outputs (handle JSON structure)
  local cosmos_account_name
  cosmos_account_name=$(jq -r '.accountNameOutput.value // .accountNameOutput // empty' "${PROVISIONING_OUTPUTS_FILE}")
  
  if [[ -n "${cosmos_account_name}" && "${cosmos_account_name}" != "null" ]]; then
    # Wait for Cosmos DB to be ready
    if ! wait_for_cosmos_db "${cosmos_account_name}"; then
      log_error "Failed to wait for Cosmos DB"
      return 1
    fi
    
    # Generate MongoDB connection string
    if ! generate_mongodb_connection_string "${cosmos_account_name}"; then
      log_error "Failed to generate MongoDB connection string"
      return 1
    fi
    
    log "MongoDB connection string: ${MONGODB_CONNECTION_STRING:0:50}..."
  fi

  local bastion_ip
  bastion_ip=$(get_vm_public_ip "${BASTION_HOST_NAME}")
  
  # Wait for bastion host to be accessible
  log "Waiting for bastion host to be accessible..."
  wait_for_vm_accessible "${bastion_ip}" "${ADMIN_USERNAME}"
  
  # Remove old host keys from known_hosts to avoid conflicts
  log "Cleaning up old SSH host keys..."
  ssh-keygen -R "${bastion_ip}" 2>/dev/null || true
  ssh-keygen -R "10.0.0.4" 2>/dev/null || true
  ssh-keygen -R "10.0.0.5" 2>/dev/null || true
  ssh-keygen -R "10.0.0.6" 2>/dev/null || true
  
  # Wait for web server to be accessible and deploy MongoDB connection string
  local web_server_ip
  web_server_ip=$(get_vm_private_ip "${WEB_SERVER_NAME}")
  
  if [[ -n "${web_server_ip}" ]]; then
    log "Waiting for web server to be accessible..."
    wait_for_vm_accessible "${web_server_ip}" "${ADMIN_USERNAME}" "${ADMIN_USERNAME}@${bastion_ip}"
    
    # Deploy MongoDB connection string
    deploy_mongodb_connection_string "${web_server_ip}" "${MONGODB_CONNECTION_STRING}"
  fi
  
  # GitHub Actions runner is configured via cloud-init on web server
  log "GitHub Actions runner will be configured automatically via cloud-init"
  
  log "Infrastructure provisioning completed"
}

# Wait for VM to be accessible via SSH
wait_for_vm_accessible() {
  local ip_address="$1"
  local username="$2"
  local proxy_jump="${3:-}"
  local attempt=0
  
  while [[ ${attempt} -lt ${MAX_RETRY_ATTEMPTS} ]]; do
    attempt=$((attempt + 1))
    
    if [[ -n "${proxy_jump}" ]]; then
      if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -o ProxyJump="${proxy_jump}" "${username}@${ip_address}" "echo 'accessible'" > /dev/null 2>&1; then
        log "VM ${ip_address} is accessible"
        return 0
      fi
    else
      if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "${username}@${ip_address}" "echo 'accessible'" > /dev/null 2>&1; then
        log "VM ${ip_address} is accessible"
        return 0
      fi
    fi
    
    log "Attempt ${attempt}/${MAX_RETRY_ATTEMPTS}: VM not accessible yet, waiting ${RETRY_DELAY_SECONDS}s..."
    sleep "${RETRY_DELAY_SECONDS}"
  done
  
  log_error "VM ${ip_address} did not become accessible after ${MAX_RETRY_ATTEMPTS} attempts"
  return 1
}

# Deploy MongoDB connection string to web server
deploy_mongodb_connection_string() {
  local web_server_ip="$1"
  local connection_string="$2"
  
  if [[ -z "${connection_string}" ]]; then
    log_warning "MongoDB connection string not available, skipping deployment"
    return 0
  fi
  
  log "Deploying MongoDB connection string to web server..."
  
  # Create appsettings.Production.json content (matching appsettings.json structure)
  local appsettings_content="{
  \"ConnectionStrings\": {
    \"MongoDB\": \"${connection_string}\"
  },
  \"MongoDB\": {
    \"DatabaseName\": \"TodoAppDb\"
  }
}"
  
  # Deploy via SSH through bastion
  local bastion_ip
  bastion_ip=$(get_vm_public_ip "${BASTION_HOST_NAME}")
  
  if [[ -z "${bastion_ip}" ]]; then
    log_error "Bastion IP not available"
    return 1
  fi
  
  # Use ProxyJump to reach web server
  if ssh -o StrictHostKeyChecking=no -o ProxyJump="${ADMIN_USERNAME}@${bastion_ip}" "${ADMIN_USERNAME}@${web_server_ip}" \
    "sudo mkdir -p /opt/GithubActionsTodoApp && \
      sudo tee /opt/GithubActionsTodoApp/appsettings.Production.json > /dev/null && \
      sudo chown www-data:www-data /opt/GithubActionsTodoApp/appsettings.Production.json && \
      sudo chmod 600 /opt/GithubActionsTodoApp/appsettings.Production.json" <<< "${appsettings_content}"; then
    log "MongoDB connection string deployed successfully"
  else
    log_error "Failed to deploy MongoDB connection string"
    return 1
  fi
}

# =============================================================================
# INFORMATION RETRIEVAL FUNCTIONS
# =============================================================================

get_vm_public_ip() {
  local vm_name="$1"

  az vm show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${vm_name}" \
    --show-details \
    --query 'publicIps' \
    --output tsv
}

get_vm_private_ip() {
  local vm_name="$1"

  az vm show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${vm_name}" \
    --show-details \
    --query 'privateIps' \
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

  local vm_names=("${WEB_SERVER_NAME}" "${REVERSE_PROXY_NAME}" "${BASTION_HOST_NAME}")

  for vm_name in "${vm_names[@]}"; do
    local public_ip
    local private_ip

    public_ip=$(get_vm_public_ip "${vm_name}")
    private_ip=$(get_vm_private_ip "${vm_name}")

    printf "%-20s Public: %-20s Private: %s\n" \
      "${vm_name}" \
      "${public_ip:-'N/A'}" \
      "${private_ip}"
  done
}

display_ssh_commands() {
  log_section "SSH Connection Commands"

  local bastion_ip
  bastion_ip=$(get_vm_public_ip "${BASTION_HOST_NAME}")

  if [[ -n "${bastion_ip}" ]]; then
    echo "Direct SSH to Bastion Host:"
    echo "  ssh ${ADMIN_USERNAME}@${bastion_ip}"
    echo ""
    echo "SSH to internal VMs via Bastion:"
    for vm_name in "${WEB_SERVER_NAME}" "${REVERSE_PROXY_NAME}"; do
      local private_ip
      private_ip=$(get_vm_private_ip "${vm_name}")
      echo "  ssh -o ProxyJump=\"${ADMIN_USERNAME}@${bastion_ip}\" ${ADMIN_USERNAME}@${private_ip}"
    done
  else
    log_warning "Bastion host IP not available"
  fi
}

# =============================================================================
# TESTING FUNCTIONS
# =============================================================================

test_reverse_proxy() {
  log_section "Testing Reverse Proxy"

  local reverse_proxy_ip
  reverse_proxy_ip=$(get_vm_public_ip "${REVERSE_PROXY_NAME}")

  if [[ -z "${reverse_proxy_ip}" ]]; then
    log_warning "Reverse proxy IP not available"
    return 1
  fi

  log "Testing HTTP connection to reverse proxy: ${reverse_proxy_ip}"

  if curl --fail --silent --max-time 10 "http://${reverse_proxy_ip}" > /dev/null; then
    log "Reverse proxy is responding"
    return 0
  else
    log_warning "Reverse proxy not responding yet"
    return 1
  fi
}

# =============================================================================
# COSMOS DB FUNCTIONS
# =============================================================================

display_cosmos_db_info() {
  log_section "Azure Cosmos DB Information"

  if [[ -f "${PROVISIONING_OUTPUTS_FILE}" ]]; then
    local cosmos_endpoint
    local cosmos_db_name
    local cosmos_collection_name

    cosmos_endpoint=$(jq -r '.cosmosDbEndpoint // empty' "${PROVISIONING_OUTPUTS_FILE}")
    cosmos_db_name=$(jq -r '.cosmosDatabaseName // empty' "${PROVISIONING_OUTPUTS_FILE}")
    cosmos_collection_name=$(jq -r '.cosmosCollectionName // empty' "${PROVISIONING_OUTPUTS_FILE}")

    if [[ -n "${cosmos_endpoint}" ]]; then
      echo "Cosmos DB Endpoint: ${cosmos_endpoint}"
      echo "Database Name: ${cosmos_db_name}"
      echo "Collection Name: ${cosmos_collection_name}"
      echo ""
      
      if [[ -n "${MONGODB_CONNECTION_STRING}" ]]; then
        echo "MongoDB Connection String:"
        echo "${MONGODB_CONNECTION_STRING}"
        echo ""
        log "Connection string has been automatically generated and configured"
      else
        echo "To get the connection string, run:"
        echo "  az cosmosdb keys list --name <cosmos-db-name> --resource-group ${RESOURCE_GROUP}"
        echo ""
        echo "Then build the connection string:"
        echo "mongodb://<account-name>:<primaryMasterKey>@<account-name>.documents.azure.com:10255/?ssl=true&retryWrites=true&w=majority"
      fi
    else
      log_warning "Cosmos DB information not available yet"
    fi
  else
    log_warning "Provisioning outputs file not found"
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  log_section "${SCRIPT_NAME}"

  validate_prerequisites
  validate_bicep_file "${SCRIPT_DIR}/${BICEP_FILE}"
  validate_cloud_init_files
  ensure_ssh_key
  create_resource_group
  provision_infrastructure
  display_vm_list
  display_connection_info
  display_ssh_commands
  display_cosmos_db_info
  test_reverse_proxy || true

  log_section "Provisioning Complete"
}

main "$@"
