namespace TodoApp.Application.DTOs;

/// <summary>
/// Data Transfer Object for Todo entity.
/// Used to transfer data between layers without exposing domain entities.
/// </summary>
public class TodoDto
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
