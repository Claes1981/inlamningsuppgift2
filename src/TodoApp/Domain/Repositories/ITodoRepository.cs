using System.Collections.Generic;
using System.Threading.Tasks;
using TodoApp.Domain.Entities;

namespace TodoApp.Domain.Repositories;

/// <summary>
/// Repository interface for Todo entities.
/// Follows Dependency Inversion Principle - Domain depends on abstractions, not concrete implementations.
/// </summary>
public interface ITodoRepository
{
    /// <summary>
    /// Gets all todo items.
    /// </summary>
    /// <returns>List of all todos.</returns>
    Task<IEnumerable<Todo>> GetAllAsync();

    /// <summary>
    /// Gets a todo item by its ID.
    /// </summary>
    /// <param name="id">The todo ID.</param>
    /// <returns>The todo item or null if not found.</returns>
    Task<Todo?> GetByIdAsync(string id);

    /// <summary>
    /// Adds a new todo item.
    /// </summary>
    /// <param name="todo">The todo to add.</param>
    /// <returns>The added todo with generated ID.</returns>
    Task<Todo> AddAsync(Todo todo);

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    /// <param name="todo">The todo to update.</param>
    /// <returns>The updated todo.</returns>
    Task<Todo> UpdateAsync(Todo todo);

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    /// <param name="id">The todo ID to delete.</param>
    /// <returns>True if deleted, false if not found.</returns>
    Task<bool> DeleteAsync(string id);
}
