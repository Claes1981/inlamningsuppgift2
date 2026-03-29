namespace TodoApp.Application.DTOs;

/// <summary>
/// Data Transfer Object for Todo entity.
/// Used to transfer data between layers without exposing domain entities.
/// Implemented as a record for value equality and immutability.
/// </summary>
public record TodoDto
{
    /// <summary>
    /// Unique identifier for the todo item.
    /// </summary>
    public string Id { get; init; } = string.Empty;

    /// <summary>
    /// Title of the todo item.
    /// </summary>
    public string Title { get; init; } = string.Empty;

    /// <summary>
    /// Description of the todo item.
    /// </summary>
    public string? Description { get; init; }

    /// <summary>
    /// Indicates whether the todo item is completed.
    /// </summary>
    public bool IsCompleted { get; init; }

    /// <summary>
    /// Date and time when the todo item was created.
    /// </summary>
    public DateTime CreatedAt { get; init; }

    /// <summary>
    /// Date and time when the todo item was last updated.
    /// </summary>
    public DateTime UpdatedAt { get; init; }

    /// <summary>
    /// Category for the todo item. Used as shard key in Cosmos DB.
    /// </summary>
    public string Category { get; init; } = "general";
}
