using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TodoApp.Application.Common;
using TodoApp.Application.DTOs;
using TodoApp.Domain.Entities;
using TodoApp.Domain.Repositories;

namespace TodoApp.Application.Services;

/// <summary>
/// Service implementation for Todo business operations.
/// Follows Single Responsibility Principle - handles application-level business logic.
/// </summary>
public class TodoService : ITodoService
{
    private readonly ITodoRepository _todoRepository;

    /// <summary>
    /// Constructor injection for dependency inversion.
    /// </summary>
    /// <param name="todoRepository">The todo repository implementation.</param>
    public TodoService(ITodoRepository todoRepository)
    {
        _todoRepository = todoRepository;
    }

    /// <summary>
    /// Gets all todo items.
    /// </summary>
    public async Task<IEnumerable<TodoDto>> GetTodosAsync()
    {
        var todos = await _todoRepository.GetAllAsync();
        return todos?.Select(MapToDto) ?? Enumerable.Empty<TodoDto>();
    }

    /// <summary>
    /// Gets a todo item by its ID.
    /// </summary>
    public async Task<TodoDto?> GetTodoByIdAsync(string id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return null;
        }

        var todo = await _todoRepository.GetByIdAsync(id);
        return todo != null ? MapToDto(todo) : null;
    }

    /// <summary>
    /// Creates a new todo item with validation.
    /// </summary>
    public async Task<TodoDto> CreateTodoAsync(CreateTodoDto dto)
    {
        if (dto == null)
        {
            throw new ArgumentNullException(nameof(dto), "CreateTodoDto cannot be null.");
        }

        // Validate input before creating domain entity
        if (string.IsNullOrWhiteSpace(dto.Title))
        {
            throw new ArgumentException("Title is required.", nameof(dto.Title));
        }

        // Domain entity will perform additional validation
        var todo = new Todo(dto.Title, dto.Description, dto.Category);
        var createdTodo = await _todoRepository.AddAsync(todo);
        return MapToDto(createdTodo);
    }

    /// <summary>
    /// Updates an existing todo item with validation.
    /// </summary>
    public async Task<TodoDto> UpdateTodoAsync(string id, UpdateTodoDto dto)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            throw new ArgumentException("ID is required.", nameof(id));
        }

        if (dto == null)
        {
            throw new ArgumentNullException(nameof(dto), "UpdateTodoDto cannot be null.");
        }

        var todo = await _todoRepository.GetByIdAsync(id);
        if (todo == null)
        {
            throw new KeyNotFoundException($"Todo with ID '{id}' not found.");
        }

        // Update title and description (domain entity validates)
        todo.Update(dto.Title, dto.Description);

        // Update completion status
        if (dto.IsCompleted && !todo.IsCompleted)
        {
            todo.MarkAsCompleted();
        }
        else if (!dto.IsCompleted && todo.IsCompleted)
        {
            todo.MarkAsNotCompleted();
        }

        // Update category if provided
        if (!string.IsNullOrWhiteSpace(dto.Category))
        {
            todo.SetCategory(dto.Category);
        }

        var updatedTodo = await _todoRepository.UpdateAsync(todo);
        return MapToDto(updatedTodo);
    }

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    public async Task<bool> DeleteTodoAsync(string id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return false;
        }

        return await _todoRepository.DeleteAsync(id);
    }

    /// <summary>
    /// Maps a Todo entity to a TodoDto.
    /// </summary>
    private static TodoDto MapToDto(Todo todo)
    {
        return new TodoDto
        {
            Id = todo.Id,
            Title = todo.Title,
            Description = todo.Description,
            IsCompleted = todo.IsCompleted,
            CreatedAt = todo.CreatedAt,
            UpdatedAt = todo.UpdatedAt,
            Category = todo.Category
        };
    }
}
