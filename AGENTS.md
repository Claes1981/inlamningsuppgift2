# Agent Instructions for Azure Infrastructure Provisioning & TodoApp

**Generated:** 2026-03-22

## Project Overview
This project provisions Azure infrastructure using Bicep templates and Bash scripts, and hosts a .NET 10.0 Todo application following Clean Architecture principles. The infrastructure includes:
- Resource Group in denmarkeast
- Virtual Network (10.0.0.0/16) with single subnet
- Network Security Group with ASG-based rules
- Three Ubuntu 24.04 LTS VMs: Web Server, Reverse Proxy, and Bastion Host
- Azure Cosmos DB with MongoDB API
- NGINX-based reverse proxy configuration
- .NET MVC Todo application with CRUD operations

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Infrastructure-as-Code | Bicep, Bash 4.0+ |
| Presentation | ASP.NET Core MVC (net10.0) |
| Application | .NET Class Library (Services, DTOs) |
| Domain | .NET Class Library (Entities, Repository interfaces) |
| Infrastructure | MongoDB.Driver 2.28.0 |
| Database | Azure Cosmos DB (MongoDB API) |
| Testing | xUnit 2.5.3, Moq 4.20.70, FluentAssertions 6.12.0 |
| API Documentation | Swashbuckle 10.1.5 (Swagger) |
| OS | Ubuntu 24.04 LTS |
| Web Server | NGINX |

## Project Structure

```
inlamningsuppgift2/
├── infra/                          # Infrastructure as Code
│   ├── infrastructure.bicep        # Azure resources (VMs, VNET, NSG, Cosmos DB)
│   ├── provisioning.sh             # Main provisioning script
│   ├── deploy_app.sh               # .NET app deployment script
│   ├── cloud-init_webserver.sh     # Web server config (NGINX, port 5000)
│   ├── cloud-init_reverseproxy.sh  # Reverse proxy config (NGINX, port 80)
│   └── cloud-init_bastion.sh       # Bastion host config (SSH)
├── src/
│   └── TodoApp/                    # .NET MVC Todo Application
│       ├── TodoApp.csproj          # Project file (net10.0)
│       ├── Program.cs              # DI container, middleware config
│       ├── appsettings.json        # Configuration
│       ├── Controllers/
│       │   ├── HomeController.cs   # MVC views
│       │   └── Presentation/Controllers/TodoController.cs  # REST API
│       ├── Domain/
│       │   ├── Entities/Todo.cs    # Domain entity
│       │   └── Repositories/ITodoRepository.cs  # Repository interface
│       ├── Application/
│       │   ├── Services/
│       │   │   ├── ITodoService.cs # Service interface
│       │   │   └── TodoService.cs  # Service implementation
│       │   └── DTOs/               # Data transfer objects
│       └── Infrastructure/
│           └── Repositories/MongoTodoRepository.cs  # MongoDB implementation
├── tests/
│   ├── TodoApp.Tests/              # Application tests
│   │   └── Application/Services/TodoServiceTests.cs
│   └── Infrastructure.Tests/       # Infrastructure validation tests
│       ├── Bicep/BicepTemplateTests.cs
│       └── Bash/ProvisioningScriptTests.cs
├── plans/
│   └── todo-app-architecture.md    # Architecture documentation
└── inlamningsuppgift2.sln          # Visual Studio solution
```

## Commands

### Infrastructure Provisioning

| Action | Command |
|--------|---------|
| Validate Bash syntax | `bash -n infra/provisioning.sh` |
| Lint Bash scripts | `shellcheck infra/provisioning.sh` |
| Validate Bicep | `az bicep build --file infra/infrastructure.bicep` |
| Build Bicep (inspect) | `az bicep build --file infra/infrastructure.bicep --stdout` |
| Provision infrastructure | `./infra/provisioning.sh` |
| Deploy .NET app | `./infra/deploy_app.sh` |

### .NET Application

| Action | Command |
|--------|---------|
| Restore dependencies | `dotnet restore` |
| Build | `dotnet build` |
| Run tests | `dotnet test` |
| Run app | `dotnet run --project src/TodoApp` |
| Publish | `dotnet publish -c Release -o ./publish` |

### Manual Testing

| Action | Command |
|--------|---------|
| Test reverse proxy | `curl http://<REVERSE_PROXY_IP>` |
| SSH to bastion | `ssh azureuser@<BASTION_IP>` |
| SSH to internal VMs | `ssh -o ProxyJump="azureuser@<BASTION_IP>" azureuser@10.0.0.4` |
| Get Cosmos DB keys | `az cosmosdb list-keys --name <cosmos-db-name> --resource-group TodoAppResourceGroup` |

## Code Style Guidelines

### Bash Scripting

#### Structure & Organization
- Use `set -euo pipefail` at script start for strict error handling
- Define all configuration as `readonly` constants at the top
- Group related constants with blank lines
- Use descriptive function names in snake_case (e.g., `create_resource_group`)
- Each function should handle a single responsibility (SRP)
- Use `log()` and `log_section()` for all output
- Implement retry logic with exponential backoff for Azure API calls

#### Naming Conventions
- Constants: SCREAMING_SNAKE_CASE (e.g., `RESOURCE_GROUP`, `NSG_NAME`)
- Functions: snake_case (e.g., `deploy_infrastructure`)
- Local variables: snake_case (e.g., `nic_name`, `ip_config_name`)
- Use `local` keyword for all function-scoped variables

#### Error Handling
- Always check command exit codes with `set -e`
- Use `wait_for_resource()` for Azure resource provisioning
- Log warnings with `log "Warning: ..."` for non-critical failures
- Implement retry logic with configurable attempts and delays
- Validate required files exist before use

### C# / .NET (Clean Architecture)

#### Architecture Layers
- **Domain**: Business entities and repository interfaces (no dependencies)
- **Application**: Services, DTOs, use cases (depends on Domain)
- **Infrastructure**: External implementations (MongoDB, depends on Domain)
- **Presentation**: Controllers, MVC (depends on Application)

#### Naming Conventions
- Classes: PascalCase (e.g., `TodoService`, `TodoController`)
- Interfaces: Prefix with `I` (e.g., `ITodoRepository`, `ITodoService`)
- DTOs: Suffix with `Dto` (e.g., `CreateTodoDto`, `UpdateTodoDto`)
- Methods: PascalCase (e.g., `GetTodosAsync`, `CreateTodoAsync`)
- Private fields: underscore prefix (e.g., `_todoService`, `_mockRepository`)

#### SOLID Principles
- **Single Responsibility**: Each class does one thing
- **Dependency Inversion**: Depend on interfaces, not concrete implementations
- **Interface Segregation**: Specific interfaces over general ones
- **Use async/await**: All I/O operations should be asynchronous

#### Testing
- Use xUnit for unit tests
- Use Moq for mocking dependencies
- Use FluentAssertions for expressive assertions
- Follow Arrange-Act-Assert pattern
- Test methods should be descriptive: `Method_WhenCondition_ExpectResult`

### Bicep Templates

#### Structure
- Use `@description()` for all parameters
- Use `@secure()` for sensitive parameters (SSH keys, passwords)
- Provide sensible defaults for non-sensitive parameters
- Use consistent resource naming: `${name}${suffix}` (e.g., `${vmName}Nic`)
- Group related resources logically with comments
- Use `dependsOn` explicitly when implicit dependencies are unclear

#### Naming Conventions
- Parameters: camelCase (e.g., `adminUsername`, `vnetAddressPrefix`)
- Resources: camelCase (e.g., `reverseProxyAsg`, `webServerVm`)
- Outputs: camelCase (e.g., `reverseProxyPublicIp`)

#### Best Practices
- Use latest stable API versions (e.g., `@2024-03-01`)
- Use Application Security Groups for traffic segmentation
- Associate NSG at subnet level, not individual NICs
- Use `standard` SKU for public IPs
- Disable password authentication on Linux VMs

### Cloud-Init (Shell Script Format)

#### Structure
- Use `#cloud-config` header on first line
- Set `package_update: true` and `package_upgrade: false`
- Use 2-space indentation for YAML
- Group packages, write_files, runcmd logically
- Base64 encode in provisioning script before passing to Bicep

## Architecture Patterns

### Clean Architecture (TodoApp)

```
Presentation (TodoController) 
    ↓ depends on interfaces
Application (TodoService, DTOs)
    ↓ depends on interfaces
Domain (Todo entity, ITodoRepository)
    ↑ implemented by
Infrastructure (MongoTodoRepository)
```

### Infrastructure Topology

```
Internet
    ↓ HTTP:80
Reverse Proxy (Public IP)
    ↓ HTTP:5000
Web Server (Private IP only) - .NET TodoApp
    ↓ MongoDB
Azure Cosmos DB (MongoDB API)

Bastion Host (Public IP)
    ↓ SSH:22
All VMs (for administrative access)
```

### Security
- SSH key authentication only (no passwords)
- Web Server has no public IP (internal only)
- Bastion Host for SSH access to internal VMs
- NSG rules follow least privilege principle
- Application Security Groups for traffic segmentation

## Common Tasks

### Adding a New VM
1. Add VM name parameter to `infrastructure.bicep`
2. Create NIC resource (with or without public IP)
3. Create VM resource with cloud-init if needed
4. Add ASG if new traffic segmentation required
5. Assign ASG to NIC IP configuration
6. Add NSG rules if new ports required

### Adding a New API Endpoint
1. Add method to `ITodoService` interface in `Application/Services/`
2. Implement in `TodoService` class
3. Add route to `TodoController` in `Presentation/Controllers/`
4. Add unit tests in `tests/TodoApp.Tests/`
5. Update Swagger documentation if needed

### Modifying Network Security
1. Add security rule to NSG in Bicep with unique priority
2. Priority order: lower numbers = higher priority
3. Use ASGs for destination when possible
4. Default deny, explicit allow rules only

### Debugging
1. Check Azure CLI auth: `az account show`
2. Verify resource group: `az group show --name TodoAppResourceGroup`
3. Check resource state: `az resource show --resource-type ...`
4. Enable verbose logging: add `--debug` to az commands
5. Check deployment outputs: `cat /tmp/provisioning_outputs.json`

## Files Reference

### Infrastructure
- `infrastructure.bicep` - Bicep template for all Azure resources
- `provisioning.sh` - Main provisioning script with SSH key handling
- `deploy_app.sh` - .NET application deployment script
- `cloud-init_webserver.sh` - Cloud-init for web server (nginx on 8080)
- `cloud-init_reverseproxy.sh` - Cloud-init for reverse proxy (nginx on 80)
- `cloud-init_bastion.sh` - Cloud-init for bastion host (SSH service)

### Application
- `src/TodoApp/Program.cs` - DI container, middleware, configuration
- `src/TodoApp/appsettings.json` - Application configuration
- `src/TodoApp/Presentation/Controllers/TodoController.cs` - REST API endpoints
- `src/TodoApp/Application/Services/TodoService.cs` - Business logic
- `src/TodoApp/Domain/Entities/Todo.cs` - Domain entity
- `src/TodoApp/Infrastructure/Repositories/MongoTodoRepository.cs` - MongoDB implementation

### Tests
- `tests/TodoApp.Tests/Application/Services/TodoServiceTests.cs` - Service layer tests
- `tests/TodoApp.Tests/Presentation/Controllers/TodoControllerTests.cs` - Controller tests
- `tests/Infrastructure.Tests/Bicep/BicepTemplateTests.cs` - Bicep validation tests
- `tests/Infrastructure.Tests/Bash/ProvisioningScriptTests.cs` - Bash script tests

## Environment Variables
No environment variables required. All configuration is in script constants or appsettings.json.

## Dependencies
- Azure CLI (az) version 2.0+
- Bicep CLI (az bicep)
- .NET 10.0 SDK
- Bash 4.0+
- Cloud-init (on VMs)
- NGINX (on VMs)
- MongoDB.Driver 2.28.0

## Notes
- Cosmos DB connection string must be updated in `appsettings.Production.json` during deployment
- The `deploy_app.sh` script automatically retrieves Cosmos DB credentials from Azure
- All VMs use Ubuntu 24.04 LTS with SSH key authentication
- The TodoApp listens on port 5000 internally, reverse proxy forwards port 80
- Swagger UI is available at `/swagger` in development mode
