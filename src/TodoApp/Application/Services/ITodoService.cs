using System.Collections.Generic;
using System.Threading.Tasks;
using TodoApp.Application.DTOs;

namespace TodoApp.Application.Services;

/// <summary>
/// Service interface for Todo business operations.
/// Follows Interface Segregation Principle - focused on Todo operations only.
/// </summary>
public interface ITodoService
{
    /// <summary>
    /// Gets all todo items.
    /// </summary>
    /// <returns>Collection of all todo items.</returns>
    Task<IEnumerable<TodoDto>> GetTodosAsync();

    /// <summary>
    /// Gets a todo item by its ID.
    /// </summary>
    /// <param name="id">The unique identifier of the todo item.</param>
    /// <returns>The todo item or null if not found.</returns>
    Task<TodoDto?> GetTodoByIdAsync(string id);

    /// <summary>
    /// Creates a new todo item.
    /// </summary>
    /// <param name="dto">The data transfer object containing todo data.</param>
    /// <returns>The created todo item.</returns>
    Task<TodoDto> CreateTodoAsync(CreateTodoDto dto);

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    /// <param name="id">The unique identifier of the todo item.</param>
    /// <param name="dto">The data transfer object containing updated todo data.</param>
    /// <returns>The updated todo item.</returns>
    Task<TodoDto> UpdateTodoAsync(string id, UpdateTodoDto dto);

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    /// <param name="id">The unique identifier of the todo item.</param>
    /// <returns>True if the todo was deleted, false otherwise.</returns>
    Task<bool> DeleteTodoAsync(string id);
}
