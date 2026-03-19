# Todo App Architecture Plan

## Overview
A .NET MVC Todo application following Clean Architecture and SOLID principles, deployed on Azure with MongoDB.

## Architecture Layers

### Clean Architecture Structure

```
src/TodoApp/
├── TodoApp.csproj              # Main MVC project (Presentation Layer)
├── Domain/                     # Domain Layer - Business entities & rules
│   ├── Entities/
│   │   └── Todo.cs
│   └── Repositories/
│       └── ITodoRepository.cs
├── Application/                # Application Layer - Use cases & DTOs
│   ├── Services/
│   │   ├── ITodoService.cs
│   │   └── TodoService.cs
│   └── DTOs/
│       ├── TodoDto.cs
│       └── CreateTodoDto.cs
├── Infrastructure/             # Infrastructure Layer - External implementations
│   └── Data/
│       └── MongoDB/
│           └── TodoRepository.cs
└── Controllers/
    └── TodoController.cs
```

### Dependency Flow (SOLID - Dependency Inversion)

```
Presentation (TodoApp) 
    ↓ depends on interfaces
Application (Services, DTOs)
    ↓ depends on interfaces
Domain (Entities, Repository interfaces)
    ↑ implemented by
Infrastructure (MongoDB implementations)
```

## Azure Infrastructure Integration

### Existing Azure Infrastructure (`infra/`)
- Resource Group, VNET, NSG
- 3 VMs: Web Server, Reverse Proxy, Bastion Host
- Ubuntu 24.04 LTS with NGINX

### New Azure Resources Needed
- **Azure MongoDB Atlas Cluster** OR **Azure Cosmos DB (MongoDB API)**
- Connection string stored in Azure Key Vault (recommended) or appsettings

### Deployment Flow
1. Provision Azure infrastructure with Bicep (`infra/infrastructure.bicep`)
2. Deploy .NET app to Web Server VM
3. Configure appsettings.json with MongoDB connection string
4. Reverse proxy routes traffic to .NET app

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Presentation | ASP.NET Core MVC |
| Domain | .NET Class Library |
| Application | .NET Class Library |
| Infrastructure | MongoDB.Driver |
| Database | Azure MongoDB Atlas / Cosmos DB |
| Infrastructure-as-Code | Bicep + Bash |

## CRUD Operations

| Operation | Controller | Service | Repository |
|-----------|-----------|---------|------------|
| Create | POST /Todo | CreateTodo() | InsertAsync() |
| Read All | GET /Todo | GetAllTodos() | FindAllAsync() |
| Read One | GET /Todo/{id} | GetTodoById() | FindByIdAsync() |
| Update | PUT /Todo/{id} | UpdateTodo() | UpdateAsync() |
| Delete | DELETE /Todo/{id} | DeleteTodo() | DeleteAsync() |

## Key Design Decisions

1. **MongoDB Choice**: Azure Cosmos DB with MongoDB API for managed service
2. **Authentication**: Not included in initial scope (can be added later)
3. **Validation**: FluentValidation in Application layer
4. **Dependency Injection**: Built-in .NET DI container
5. **Configuration**: appsettings.json with environment overrides
