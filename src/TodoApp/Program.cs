using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using TodoApp.Application.Services;
using TodoApp.Domain.Repositories;
using TodoApp.Infrastructure.Repositories;

var builder = WebApplication.CreateBuilder(args);

// =============================================================================
// Configuration Validation
// =============================================================================

// Add MongoDB configuration with validation
var mongoConnectionString = builder.Configuration.GetConnectionString("MongoDB")
    ?? throw new InvalidOperationException("MongoDB connection string is required but not found.");

var databaseName = builder.Configuration.GetValue<string>("MongoDB:DatabaseName") ?? "TodoApp";

// =============================================================================
// Service Registration
// =============================================================================

// Register MongoDB client as singleton
builder.Services.AddSingleton<IMongoClient>(sp =>
{
    return new MongoClient(mongoConnectionString);
});

// Register repository (Infrastructure layer) - Scoped for request lifetime
builder.Services.AddScoped<ITodoRepository>(sp =>
{
    var mongoClient = sp.GetRequiredService<IMongoClient>();
    var logger = sp.GetRequiredService<ILogger<MongoTodoRepository>>();
    return new MongoTodoRepository(mongoClient, databaseName, "todos", logger);
});

// Register service (Application layer) - Scoped for request lifetime
builder.Services.AddScoped<ITodoService, TodoService>();

// =============================================================================
// MVC & API Configuration
// =============================================================================

// Add MVC with views and API behavior
builder.Services.AddControllersWithViews(options =>
{
    // Enable API explorer for Swagger
    options.RespectBrowserAcceptHeader = true;
});

// Add Swagger/OpenAPI for API documentation
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new()
    {
        Title = "Todo API",
        Version = "v1",
        Description = "A Clean Architecture Todo API with CRUD operations"
    });
});

// =============================================================================
// CORS Configuration
// =============================================================================

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// =============================================================================
// Health Checks
// =============================================================================

builder.Services.AddHealthChecks();

// =============================================================================
// Application Build
// =============================================================================

var app = builder.Build();

// =============================================================================
// Request Pipeline Configuration
// =============================================================================

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Todo API v1");
        c.RoutePrefix = string.Empty; // Swagger UI at root
    });
}
else
{
    // Global error handling for production
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

// Enable CORS
app.UseCors("AllowAll");

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

// =============================================================================
// Route Configuration
// =============================================================================

// Default MVC route
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// API controllers
app.MapControllers();

// =============================================================================
// Health Check Endpoints
// =============================================================================

app.MapHealthChecks("/health");

// =============================================================================
// Server Configuration
// =============================================================================

// Configure Kestrel to listen on port 5000 (for reverse proxy)
app.Urls.Add("http://*:5000");

// =============================================================================
// Application Startup
// =============================================================================

try
{
    app.Run();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Fatal error: {ex.Message}");
    Environment.Exit(1);
}
