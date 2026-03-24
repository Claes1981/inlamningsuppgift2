#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="TodoApp Deployment"
readonly RESOURCE_GROUP="TodoAppResourceGroup"
readonly WEB_SERVER_NAME="WebServer"
readonly BASTION_HOST_NAME="BastionHost"
readonly REVERSE_PROXY_NAME="ReverseProxy"
readonly ADMIN_USERNAME="azureuser"
readonly SSH_KEY_FILE="${HOME}/.ssh/id_rsa"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${SCRIPT_DIR}/../src/TodoApp"
readonly PUBLISH_DIR="${SCRIPT_DIR}/publish"

readonly MAX_RETRY_ATTEMPTS=30
readonly RETRY_DELAY_SECONDS=2
readonly HEALTH_CHECK_ENDPOINT="/health"

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
    log_error "Deployment failed with exit code: ${exit_code}"
    log "To retry, run: ${BASH_SOURCE[0]}"
  fi
  
  # Clean up publish directory on success
  if [[ ${exit_code} -eq 0 ]] && [[ -d "${PUBLISH_DIR}" ]]; then
    log "Cleaning up publish directory..."
    rm -rf "${PUBLISH_DIR}"
  fi
}

trap cleanup EXIT

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_prerequisites() {
  log "Validating prerequisites..."

  local prerequisites=("dotnet" "ssh" "scp" "az")
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

  if [[ ! -f "${SSH_KEY_FILE}" ]]; then
    log_error "SSH private key not found: ${SSH_KEY_FILE}"
    log "Generate one using: ssh-keygen -t rsa -b 4096 -f ${SSH_KEY_FILE}"
    return 1
  fi

  if [[ ! -d "${PROJECT_DIR}" ]]; then
    log_error "Project directory not found: ${PROJECT_DIR}"
    return 1
  fi

  log "All prerequisites validated"
}

# =============================================================================
# AZURE RESOURCE FUNCTIONS
# =============================================================================

get_vm_public_ip() {
  local vm_name="$1"

  az vm show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${vm_name}" \
    --show-details \
    --query 'publicIps' \
    --output tsv 2>/dev/null || echo ""
}

get_vm_private_ip() {
  local vm_name="$1"

  az vm show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${vm_name}" \
    --show-details \
    --query 'privateIps' \
    --output tsv 2>/dev/null || echo ""
}

get_cosmos_db_connection_string() {
  log "Retrieving Cosmos DB connection string..."

  local deployment_name="infra-bicep-deployment"
  local cosmos_name
  local primary_key
  local endpoint

  # Get Cosmos DB name from deployment outputs
  cosmos_name=$(az deployment group show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${deployment_name}" \
    --query 'properties.outputs.cosmosDbName.value' \
    --output tsv 2>/dev/null) || {
    log_error "Failed to get Cosmos DB name from deployment outputs"
    return 1
  }

  # Get Cosmos DB keys
  primary_key=$(az cosmosdb list-keys \
    --name "${cosmos_name}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query 'primaryMasterKey' \
    --output tsv 2>/dev/null) || {
    log_error "Failed to get Cosmos DB keys"
    return 1
  }

  # Construct connection string
  endpoint="${cosmos_name}.mongo.cosmos.azure.com"

  echo "mongodb+srv://${endpoint}:10255/?ssl=true&replicaSet=globaldb&authSource=admin&authMechanism=SCRAM-SHA-256&password=${primary_key}"
}

# =============================================================================
# DEPLOYMENT FUNCTIONS
# =============================================================================

publish_app() {
  log_section "Publishing .NET Application"

  log "Publishing application from: ${PROJECT_DIR}"

  # Clean previous publish
  rm -rf "${PUBLISH_DIR}"
  mkdir -p "${PUBLISH_DIR}"

  # Publish the application
  cd "${PROJECT_DIR}"
  dotnet publish -c Release -o "${PUBLISH_DIR}" --verbosity quiet

  if [[ ! -f "${PUBLISH_DIR}/TodoApp.dll" ]]; then
    log_error "Publish failed - TodoApp.dll not found"
    return 1
  fi

  log "Application published successfully to: ${PUBLISH_DIR}"
}

create_appsettings() {
  local cosmos_connection_string="$1"

  log "Creating appsettings.Production.json..."

  cat > "${PUBLISH_DIR}/appsettings.Production.json" << EOF
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "MongoDB": "${cosmos_connection_string}"
  },
  "MongoDB": {
    "DatabaseName": "TodoAppDb",
    "CollectionName": "todos"
  }
}
EOF

  log "appsettings.Production.json created"
}

deploy_to_server() {
  local web_server_ip="$1"
  local bastion_ip="$2"

  log_section "Deploying to Web Server"

  log "Web Server IP: ${web_server_ip}"
  log "Bastion Host IP: ${bastion_ip}"

  local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
  local scp_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
  local proxy_jump="-o ProxyJump=\"${ADMIN_USERNAME}@${bastion_ip}\""

  # Create remote directory
  log "Creating remote directory..."
  ssh ${ssh_opts} ${proxy_jump} "${ADMIN_USERNAME}@${web_server_ip}" \
    "mkdir -p /home/${ADMIN_USERNAME}/TodoApp/publish" || {
    log_error "Failed to create remote directory"
    return 1
  }

  # Copy published files
  log "Copying application files..."
  scp ${scp_opts} ${proxy_jump} \
    "${PUBLISH_DIR}"/* \
    "${ADMIN_USERNAME}@${web_server_ip}:/home/${ADMIN_USERNAME}/TodoApp/publish/" || {
    log_error "Failed to copy application files"
    return 1
  }

  # Set permissions
  log "Setting permissions..."
  ssh ${ssh_opts} ${proxy_jump} "${ADMIN_USERNAME}@${web_server_ip}" \
    "chown -R ${ADMIN_USERNAME}:${ADMIN_USERNAME} /home/${ADMIN_USERNAME}/TodoApp" || {
    log_error "Failed to set permissions"
    return 1
  }

  # Restart the service
  log "Restarting TodoApp service..."
  ssh ${ssh_opts} ${proxy_jump} "${ADMIN_USERNAME}@${web_server_ip}" \
    "sudo systemctl restart todoapp.service" || {
    log_error "Failed to restart service"
    return 1
  }

  log "Application deployed successfully"
}

# =============================================================================
# HEALTH CHECK FUNCTIONS
# =============================================================================

wait_for_service() {
  local web_server_ip="$1"
  local bastion_ip="$2"
  local service_name="$3"

  log "Waiting for ${service_name} to start..."

  local attempt=0
  local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
  local proxy_jump="-o ProxyJump=\"${ADMIN_USERNAME}@${bastion_ip}\""

  while [[ ${attempt} -lt ${MAX_RETRY_ATTEMPTS} ]]; do
    attempt=$((attempt + 1))

    local service_status
    service_status=$(ssh ${ssh_opts} ${proxy_jump} "${ADMIN_USERNAME}@${web_server_ip}" \
      "systemctl is-active ${service_name}.service" 2>/dev/null || echo "inactive")

    if [[ "${service_status}" == "active" ]]; then
      log "${service_name} is running"
      return 0
    fi

    log "Attempt ${attempt}/${MAX_RETRY_ATTEMPTS}: ${service_name} is ${service_status}, waiting ${RETRY_DELAY_SECONDS}s..."
    sleep "${RETRY_DELAY_SECONDS}"
  done

  log_error "${service_name} did not start within timeout"
  return 1
}

test_health_endpoint() {
  local reverse_proxy_ip="$1"

  log_section "Testing Health Endpoint"

  log "Testing health endpoint at http://${reverse_proxy_ip}${HEALTH_CHECK_ENDPOINT}"

  local attempt=0
  while [[ ${attempt} -lt ${MAX_RETRY_ATTEMPTS} ]]; do
    attempt=$((attempt + 1))

    if curl --fail --silent --max-time 5 "http://${reverse_proxy_ip}${HEALTH_CHECK_ENDPOINT}" > /dev/null 2>&1; then
      log "Health check passed!"
      return 0
    fi

    log "Attempt ${attempt}/${MAX_RETRY_ATTEMPTS}: Health check failed, waiting ${RETRY_DELAY_SECONDS}s..."
    sleep "${RETRY_DELAY_SECONDS}"
  done

  log_warning "Health check did not pass within timeout"
  log "You can manually test: curl http://${reverse_proxy_ip}${HEALTH_CHECK_ENDPOINT}"
  return 1
}

# =============================================================================
# INFORMATION DISPLAY FUNCTIONS
# =============================================================================

display_deployment_summary() {
  local reverse_proxy_ip="$1"

  log_section "Deployment Summary"

  echo "Application deployed successfully!"
  echo ""
  echo "Access URLs:"
  echo "  - TodoApp (via Reverse Proxy): http://${reverse_proxy_ip}"
  echo "  - Swagger UI: http://${reverse_proxy_ip}/swagger"
  echo "  - Health Check: http://${reverse_proxy_ip}/health"
  echo ""
  echo "SSH Access:"
  echo "  - Bastion Host: ssh ${ADMIN_USERNAME}@${BASTION_HOST_NAME}"
  echo "  - Web Server: ssh -o ProxyJump=\"${ADMIN_USERNAME}@${BASTION_HOST_NAME}\" ${ADMIN_USERNAME}@10.0.0.4"
  echo ""
  echo "Service Management:"
  echo "  - View logs: ssh -o ProxyJump=\"${ADMIN_USERNAME}@${BASTION_HOST_NAME}\" ${ADMIN_USERNAME}@10.0.0.4 'sudo journalctl -u todoapp.service -f'"
  echo "  - Restart: ssh -o ProxyJump=\"${ADMIN_USERNAME}@${BASTION_HOST_NAME}\" ${ADMIN_USERNAME}@10.0.0.4 'sudo systemctl restart todoapp.service'"
  echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  log_section "${SCRIPT_NAME}"

  # Validate prerequisites
  validate_prerequisites

  # Get VM IPs
  log_section "Retrieving Azure Resources"

  local web_server_ip
  local bastion_ip
  local reverse_proxy_ip

  web_server_ip=$(get_vm_private_ip "${WEB_SERVER_NAME}")
  if [[ -z "${web_server_ip}" ]]; then
    log_error "Could not retrieve Web Server private IP"
    log "Ensure infrastructure is provisioned first: ./provisioning.sh"
    exit 1
  fi

  bastion_ip=$(get_vm_public_ip "${BASTION_HOST_NAME}")
  if [[ -z "${bastion_ip}" ]]; then
    log_error "Could not retrieve Bastion Host public IP"
    exit 1
  fi

  reverse_proxy_ip=$(get_vm_public_ip "${REVERSE_PROXY_NAME}")
  if [[ -z "${reverse_proxy_ip}" ]]; then
    log_error "Could not retrieve Reverse Proxy public IP"
    exit 1
  fi

  log "Web Server (Private): ${web_server_ip}"
  log "Bastion Host (Public): ${bastion_ip}"
  log "Reverse Proxy (Public): ${reverse_proxy_ip}"

  # Get Cosmos DB connection string
  local cosmos_connection_string
  cosmos_connection_string=$(get_cosmos_db_connection_string) || {
    log_error "Failed to retrieve Cosmos DB connection string"
    exit 1
  }

  # Publish application
  publish_app

  # Create production appsettings
  create_appsettings "${cosmos_connection_string}"

  # Deploy to web server
  deploy_to_server "${web_server_ip}" "${bastion_ip}"

  # Wait for service to start
  wait_for_service "${web_server_ip}" "${bastion_ip}" "todoapp"

  # Test health endpoint
  test_health_endpoint "${reverse_proxy_ip}" || true

  # Display summary
  display_deployment_summary "${reverse_proxy_ip}"
}

# Run main function
main "$@"
