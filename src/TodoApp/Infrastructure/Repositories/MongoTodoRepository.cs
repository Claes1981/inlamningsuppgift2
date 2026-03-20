using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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

    /// <summary>
    /// Constructor injection for dependency inversion.
    /// </summary>
    /// <param name="mongoClient">The MongoDB client.</param>
    /// <param name="databaseName">The name of the MongoDB database.</param>
    /// <param name="collectionName">The name of the todos collection.</param>
    public MongoTodoRepository(IMongoClient mongoClient, string databaseName, string collectionName = "todos")
    {
        var database = mongoClient.GetDatabase(databaseName);
        _todosCollection = database.GetCollection<Todo>(collectionName);
    }

    /// <summary>
    /// Gets all todo items.
    /// </summary>
    public async Task<IEnumerable<Todo>> GetAllAsync()
    {
        return await _todosCollection.Find(_ => true).ToListAsync();
    }

    /// <summary>
    /// Gets a todo item by its ID.
    /// </summary>
    public async Task<Todo?> GetByIdAsync(string id)
    {
        return await _todosCollection.Find(t => t.Id == id).FirstOrDefaultAsync();
    }

    /// <summary>
    /// Adds a new todo item.
    /// </summary>
    public async Task<Todo> AddAsync(Todo todo)
    {
        await _todosCollection.InsertOneAsync(todo);
        return todo;
    }

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    public async Task<Todo> UpdateAsync(Todo todo)
    {
        var result = await _todosCollection.ReplaceOneAsync(
            t => t.Id == todo.Id,
            todo
        );

        if (result.ModifiedCount == 0)
        {
            throw new KeyNotFoundException($"Todo with ID {todo.Id} not found");
        }

        return todo;
    }

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    public async Task<bool> DeleteAsync(string id)
    {
        var result = await _todosCollection.DeleteOneAsync(t => t.Id == id);
        return result.DeletedCount > 0;
    }
}
