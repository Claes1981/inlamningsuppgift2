using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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
    public async Task<IEnumerable<TodoDto>> GetAllAsync()
    {
        var todos = await _todoRepository.GetAllAsync();
        return todos.Select(MapToDto);
    }

    /// <summary>
    /// Gets a todo item by its ID.
    /// </summary>
    public async Task<TodoDto?> GetByIdAsync(string id)
    {
        var todo = await _todoRepository.GetByIdAsync(id);
        return todo != null ? MapToDto(todo) : null;
    }

    /// <summary>
    /// Creates a new todo item.
    /// </summary>
    public async Task<TodoDto> CreateAsync(CreateTodoDto dto)
    {
        var todo = new Todo
        {
            Title = dto.Title,
            Description = dto.Description,
            IsCompleted = false
        };

        var createdTodo = await _todoRepository.AddAsync(todo);
        return MapToDto(createdTodo);
    }

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    public async Task<TodoDto> UpdateAsync(string id, UpdateTodoDto dto)
    {
        var todo = await _todoRepository.GetByIdAsync(id);
        if (todo == null)
        {
            throw new KeyNotFoundException($"Todo with ID {id} not found");
        }

        todo.Update(dto.Title, dto.Description);

        if (dto.IsCompleted && !todo.IsCompleted)
        {
            todo.MarkAsCompleted();
        }
        else if (!dto.IsCompleted && todo.IsCompleted)
        {
            todo.MarkAsNotCompleted();
        }

        var updatedTodo = await _todoRepository.UpdateAsync(todo);
        return MapToDto(updatedTodo);
    }

    /// <summary>
    /// Deletes a todo item.
    /// </summary>
    public async Task<bool> DeleteAsync(string id)
    {
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
            UpdatedAt = todo.UpdatedAt
        };
    }
}
