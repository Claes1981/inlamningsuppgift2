# Agent Instructions for Azure Infrastructure Provisioning & TodoApp

## Project Overview
Azure infrastructure (Bicep + Bash) hosting a .NET 10.0 Todo MVC app with Clean Architecture.

## Commands

### Infrastructure
| Action | Command |
|--------|---------|
| Validate Bash | `bash -n infra/provisioning.sh` |
| Lint Bash | `shellcheck infra/provisioning.sh` |
| Validate Bicep | `az bicep build --file infra/infrastructure.bicep` |
| Provision | `./infra/provisioning.sh` |
| Deploy app | `./infra/deploy_app.sh` |

### .NET Application
| Action | Command |
|--------|---------|
| Build | `dotnet build` |
| Run all tests | `dotnet test` |
| Run single test | `dotnet test --filter "FullyQualifiedName~TestName"` |
| Run tests by class | `dotnet test --filter "FullyQualifiedName~TodoServiceTests"` |
| Run app | `dotnet run --project src/TodoApp` |
| Publish | `dotnet publish -c Release -o ./publish` |

## Code Style Guidelines

### C# / .NET

#### Imports
- System namespaces first, then third-party, then project namespaces
- Use explicit `using` statements, no `using static`
- Group related imports together

#### Formatting
- 4 spaces for indentation (no tabs)
- Opening braces on same line for methods/classes
- Empty lines between methods and logical sections
- Max 120 characters per line
- Use `#region` for grouping related test methods

#### Types
- Prefer `string` over `String`, `int` over `Int32`
- Use nullable reference types: `string?` for optional strings
- Use `IEnumerable<T>` for returns, `List<T>` for parameters
- Prefer `record` for DTOs, `class` for entities

#### Naming Conventions
- Classes: PascalCase (`TodoService`, `TodoController`)
- Interfaces: `I` prefix (`ITodoRepository`, `ITodoService`)
- DTOs: Suffix with `Dto` (`CreateTodoDto`, `UpdateTodoDto`)
- Methods: PascalCase (`GetTodosAsync`, `CreateTodoAsync`)
- Private fields: underscore prefix (`_todoService`, `_mockRepository`)
- Constants: PascalCase (`MaxTitleLength`)
- Test methods: `Method_WhenCondition_ExpectResult`

#### Error Handling
- Throw specific exceptions (`ArgumentException`, `ArgumentNullException`, `KeyNotFoundException`)
- Validate input at method boundaries
- Use `try/catch` only when you can handle the exception meaningfully
- Return `null` or empty collections instead of throwing for "not found"

#### Async/Await
- All I/O operations must be asynchronous
- Method names end with `Async`
- Use `await` instead of `.Result` or `.Wait()`
- Return `Task<ActionResult<T>>` in controllers

#### Architecture (Clean Architecture)
- **Domain**: Entities and repository interfaces (no dependencies)
- **Application**: Services and DTOs (depends on Domain)
- **Infrastructure**: External implementations (depends on Domain)
- **Presentation**: Controllers (depends on Application)
- Depend on interfaces, not concrete implementations

### Bash Scripting

#### Structure
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Define `readonly` constants at top in SCREAMING_SNAKE_CASE
- Use `local` for function-scoped variables
- Each function handles one responsibility

#### Naming
- Functions: snake_case (`create_resource_group`, `validate_prerequisites`)
- Variables: snake_case (`nic_name`, `ip_config_name`)
- Constants: SCREAMING_SNAKE_CASE (`RESOURCE_GROUP`, `MAX_RETRY_ATTEMPTS`)

#### Error Handling
- Use `set -euo pipefail` for strict mode
- Check command exit codes
- Implement retry logic with exponential backoff
- Use `log_error()` for errors, `log_warning()` for warnings

### Bicep Templates

#### Structure
- Use `@description()` for all parameters
- Use `@secure()` for sensitive values
- Provide defaults for non-sensitive parameters
- Group related resources with comments

#### Naming
- Parameters/Resources/Outputs: camelCase (`adminUsername`, `webServerVm`)
- Resource naming: `${name}${suffix}` (`${vmName}Nic`)

#### Best Practices
- Use latest stable API versions
- Use Application Security Groups for NSG rules
- Associate NSG at subnet level
- Use `standard` SKU for public IPs

### Testing (xUnit)

#### Structure
- Follow Arrange-Act-Assert pattern
- One assertion per test when possible
- Use `#region` to group tests by method

#### Mocking
- Use Moq for dependencies
- Setup mocks in constructor or test method
- Verify mock interactions with `Verify()`

#### Assertions
- Use FluentAssertions (`Should().Be()`, `Should().NotBeNull()`)
- Use `Assert.ThrowsAsync<T>()` for exception tests
- Descriptive test names: `Method_WhenCondition_ExpectResult`

## Infrastructure Topology
```
Internet → Reverse Proxy (port 80) → Web Server (port 5000) → Cosmos DB
                    ↓
              Bastion Host (SSH access to all VMs)
```

## Key Files
- `infra/infrastructure.bicep` - Azure resources
- `infra/provisioning.sh` - Main deployment script
- `src/TodoApp/Program.cs` - DI container, middleware
- `src/TodoApp/Presentation/Controllers/TodoController.cs` - REST API
- `src/TodoApp/Application/Services/TodoService.cs` - Business logic
- `tests/TodoApp.Tests/` - Unit tests
