namespace TodoApp.Domain.Entities;

/// <summary>
/// Represents a todo item in the application.
/// Follows Single Responsibility Principle - only contains domain data and logic.
/// </summary>
public class Todo
{
    /// <summary>
    /// Unique identifier for the todo item.
    /// </summary>
    public string Id { get; set; } = Guid.NewGuid().ToString();

    /// <summary>
    /// Title of the todo item.
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// Description of the todo item.
    /// </summary>
    public string? Description { get; set; }

    /// <summary>
    /// Indicates whether the todo item is completed.
    /// </summary>
    public bool IsCompleted { get; set; }

    /// <summary>
    /// Date and time when the todo item was created.
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when the todo item was last updated.
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Marks the todo item as completed.
    /// </summary>
    public void MarkAsCompleted()
    {
        IsCompleted = true;
        UpdatedAt = DateTime.UtcNow;
    }

    /// <summary>
    /// Marks the todo item as not completed.
    /// </summary>
    public void MarkAsNotCompleted()
    {
        IsCompleted = false;
        UpdatedAt = DateTime.UtcNow;
    }

    /// <summary>
    /// Updates the title and description of the todo item.
    /// </summary>
    /// <param name="title">New title.</param>
    /// <param name="description">New description.</param>
    public void Update(string title, string? description)
    {
        Title = title;
        Description = description;
        UpdatedAt = DateTime.UtcNow;
    }
}
