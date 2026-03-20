namespace TodoApp.Application.DTOs;

/// <summary>
/// Data Transfer Object for updating an existing Todo.
/// Contains all fields that can be modified.
/// </summary>
public class UpdateTodoDto
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsCompleted { get; set; }
}
