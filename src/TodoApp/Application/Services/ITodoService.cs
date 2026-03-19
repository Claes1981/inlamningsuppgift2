using System.Collections.Generic;
using System.Threading.Tasks;
using TodoApp.Application.DTOs;

namespace TodoApp.Application.Services;

/// <summary>
/// Service interface for Todo business operations.
/// Follows Dependency Inversion Principle.
/// </summary>
public interface ITodoService
{
    /// <summary>
    /// Gets all todo items.
    /// </summary>
    /// <returns>List of all todo DTOs.</returns>
    Task<IEnumerable<TodoDto>> GetAllAsync();

    /// <summary>
    /// Gets a todo item by its ID.
    /// </summary>
    /// <param name="id">The todo ID.</param>
    /// <returns>The todo DTO or null if not found.</returns>
    Task<TodoDto?> GetByIdAsync(string id);

    /// <summary>
    /// Creates a new todo item.
    /// </summary>
    /// <param name="dto">The create todo DTO.</param>
    /// <returns>The created todo DTO.</returns>
    Task<TodoDto> CreateAsync(CreateTodoDto dto);

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    /// <param name="id">The todo ID.</param>
    /// <param name="dto">The update todo DTO.</param>
    /// <returns>The updated todo DTO.</returns>
    Task<TodoDto> UpdateAsync(string id, UpdateTodoDto dto);

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    /// <param name="id">The todo ID to delete.</param>
    /// <returns>True if deleted, false if not found.</returns>
    Task<bool> DeleteAsync(string id);
}
