using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MongoDB.Driver;
using TodoApp.Domain.Entities;
using TodoApp.Domain.Repositories;

namespace TodoApp.Infrastructure.Repositories;

/// <summary>
/// MongoDB implementation of the Todo repository.
/// Follows Single Responsibility Principle - handles data persistence only.
/// </summary>
public class MongoTodoRepository : ITodoRepository
{
    private readonly IMongoCollection<Todo> _todosCollection;
    private readonly ILogger<MongoTodoRepository> _logger;

    /// <summary>
    /// Constructor injection for dependency inversion.
    /// </summary>
    /// <param name="mongoClient">The MongoDB client.</param>
    /// <param name="databaseName">The name of the MongoDB database.</param>
    /// <param name="collectionName">The name of the todos collection (default: "todos").</param>
    /// <param name="logger">Logger for diagnostic output.</param>
    public MongoTodoRepository(
        IMongoClient mongoClient,
        string databaseName,
        string collectionName = "todos",
        ILogger<MongoTodoRepository>? logger = null)
    {
        if (string.IsNullOrWhiteSpace(databaseName))
        {
            throw new ArgumentException("Database name cannot be null or empty.", nameof(databaseName));
        }

        _logger = logger;
        var database = mongoClient.GetDatabase(databaseName);
        _todosCollection = database.GetCollection<Todo>(collectionName);
    }

    /// <summary>
    /// Gets all todo items.
    /// </summary>
    public async Task<IEnumerable<Todo>> GetAllAsync()
    {
        try
        {
            _logger?.LogDebug("Fetching all todo items from MongoDB");
            var todos = await _todosCollection.Find(_ => true).ToListAsync();
            _logger?.LogDebug("Fetched {Count} todo items", todos.Count);
            return todos;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error fetching all todo items from MongoDB");
            throw;
        }
    }

    /// <summary>
    /// Gets a todo item by its ID.
    /// </summary>
    public async Task<Todo?> GetByIdAsync(string id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            _logger?.LogWarning("Attempted to fetch todo with null or empty ID");
            return null;
        }

        try
        {
            _logger?.LogDebug("Fetching todo with ID: {TodoId}", id);
            var todo = await _todosCollection.Find(t => t.Id == id).FirstOrDefaultAsync();
            if (todo == null)
            {
                _logger?.LogDebug("Todo with ID {TodoId} not found", id);
            }
            return todo;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error fetching todo with ID: {TodoId}", id);
            throw;
        }
    }

    /// <summary>
    /// Adds a new todo item.
    /// </summary>
    public async Task<Todo> AddAsync(Todo todo)
    {
        if (todo == null)
        {
            throw new ArgumentNullException(nameof(todo), "Todo cannot be null.");
        }

        try
        {
            _logger?.LogDebug("Adding new todo with ID: {TodoId}", todo.Id);
            await _todosCollection.InsertOneAsync(todo);
            _logger?.LogDebug("Successfully added todo with ID: {TodoId}", todo.Id);
            return todo;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error adding todo with ID: {TodoId}", todo?.Id);
            throw;
        }
    }

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    public async Task<Todo> UpdateAsync(Todo todo)
    {
        if (todo == null)
        {
            throw new ArgumentNullException(nameof(todo), "Todo cannot be null.");
        }

        try
        {
            _logger?.LogDebug("Updating todo with ID: {TodoId}", todo.Id);
            var result = await _todosCollection.ReplaceOneAsync(
                t => t.Id == todo.Id,
                todo
            );

            if (result.ModifiedCount == 0)
            {
                _logger?.LogWarning("Todo with ID {TodoId} not found for update", todo.Id);
                throw new KeyNotFoundException($"Todo with ID '{todo.Id}' not found.");
            }

            _logger?.LogDebug("Successfully updated todo with ID: {TodoId}", todo.Id);
            return todo;
        }
        catch (Exception ex) when (!(ex is KeyNotFoundException))
        {
            _logger?.LogError(ex, "Error updating todo with ID: {TodoId}", todo?.Id);
            throw;
        }
    }

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    public async Task<bool> DeleteAsync(string id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            _logger?.LogWarning("Attempted to delete todo with null or empty ID");
            return false;
        }

        try
        {
            _logger?.LogDebug("Deleting todo with ID: {TodoId}", id);
            var result = await _todosCollection.DeleteOneAsync(t => t.Id == id);
            
            if (result.DeletedCount > 0)
            {
                _logger?.LogDebug("Successfully deleted todo with ID: {TodoId}", id);
            }
            else
            {
                _logger?.LogDebug("Todo with ID {TodoId} not found for deletion", id);
            }

            return result.DeletedCount > 0;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error deleting todo with ID: {TodoId}", id);
            throw;
        }
    }
}
