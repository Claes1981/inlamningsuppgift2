using Microsoft.AspNetCore.Routing;
using MongoDB.Driver;
using TodoApp.Application.Services;
using TodoApp.Domain.Repositories;
using TodoApp.Infrastructure.Repositories;

var builder = WebApplication.CreateBuilder(args);

// Add MongoDB configuration
var mongoConnectionString = builder.Configuration.GetConnectionString("MongoDB") 
    ?? throw new InvalidOperationException("MongoDB connection string not found");
var databaseName = builder.Configuration.GetValue<string>("MongoDB:DatabaseName") 
    ?? "TodoApp";

// Register MongoDB client
builder.Services.AddSingleton<IMongoClient>(sp =>
{
    return new MongoClient(mongoConnectionString);
});

// Register repository (Infrastructure layer)
builder.Services.AddScoped<ITodoRepository>(sp =>
{
    var mongoClient = sp.GetRequiredService<IMongoClient>();
    return new MongoTodoRepository(mongoClient, databaseName);
});

// Register service (Application layer)
builder.Services.AddScoped<ITodoService, TodoService>();

// Add MVC with views
builder.Services.AddControllersWithViews();

// Add Swagger for API documentation
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new()
    {
        Title = "Todo API",
        Version = "v1",
        Description = "A clean architecture Todo API with CRUD operations"
    });
});

// Add CORS for frontend access
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Todo API v1");
    });
}

// Enable CORS
app.UseCors("AllowAll");

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseAuthorization();

// Configure default route to Todo controller
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Todo}/{action=Index}/{id?}");

// Map controllers for API endpoints
app.MapControllers();

app.Run();
