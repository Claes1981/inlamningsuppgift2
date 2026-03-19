namespace TodoApp.Application.DTOs;

/// <summary>
/// Data Transfer Object for creating a new Todo.
/// Contains only the required fields for creation.
/// </summary>
public class CreateTodoDto
{
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
}
