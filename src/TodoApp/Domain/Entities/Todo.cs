namespace TodoApp.Domain.Entities;

/// <summary>
/// Represents a todo item in the application.
/// Follows Single Responsibility Principle - contains domain data and business rules.
/// </summary>
public class Todo
{
    private const int MaxTitleLength = 200;
    private const int MaxDescriptionLength = 1000;

    /// <summary>
    /// Unique identifier for the todo item.
    /// </summary>
    public string Id { get; private set; } = Guid.NewGuid().ToString("N");

    /// <summary>
    /// Title of the todo item. Cannot be empty or exceed MaxTitleLength.
    /// </summary>
    public string Title { get; private set; } = string.Empty;

    /// <summary>
    /// Description of the todo item. Optional, cannot exceed MaxDescriptionLength.
    /// </summary>
    public string? Description { get; private set; }

    /// <summary>
    /// Indicates whether the todo item is completed.
    /// </summary>
    public bool IsCompleted { get; private set; }

    /// <summary>
    /// Date and time when the todo item was created. Immutable after creation.
    /// </summary>
    public DateTime CreatedAt { get; private set; } = DateTime.UtcNow;

    /// <summary>
    /// Date and time when the todo item was last updated.
    /// </summary>
    public DateTime UpdatedAt { get; private set; } = DateTime.UtcNow;

    /// <summary>
    /// Creates a new todo item with validation.
    /// </summary>
    /// <param name="title">The title of the todo item.</param>
    /// <param name="description">Optional description of the todo item.</param>
    /// <exception cref="ArgumentException">Thrown when title is invalid.</exception>
    public Todo(string title, string? description = null)
    {
        ValidateTitle(title);
        ValidateDescription(description);

        Title = title.Trim();
        Description = description?.Trim();
        CreatedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }

    /// <summary>
    /// Constructor for deserialization (MongoDB).
    /// </summary>
    private Todo()
    {
    }

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
    /// Updates the title and description of the todo item with validation.
    /// </summary>
    /// <param name="title">New title.</param>
    /// <param name="description">New description.</param>
    /// <exception cref="ArgumentException">Thrown when title or description is invalid.</exception>
    public void Update(string title, string? description)
    {
        ValidateTitle(title);
        ValidateDescription(description);

        Title = title.Trim();
        Description = description?.Trim();
        UpdatedAt = DateTime.UtcNow;
    }

    /// <summary>
    /// Validates the title.
    /// </summary>
    private static void ValidateTitle(string title)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            throw new ArgumentException("Title cannot be empty or whitespace.", nameof(title));
        }

        if (title.Length > MaxTitleLength)
        {
            throw new ArgumentException($"Title cannot exceed {MaxTitleLength} characters.", nameof(title));
        }
    }

    /// <summary>
    /// Validates the description.
    /// </summary>
    private static void ValidateDescription(string? description)
    {
        if (description != null && description.Length > MaxDescriptionLength)
        {
            throw new ArgumentException($"Description cannot exceed {MaxDescriptionLength} characters.", nameof(description));
        }
    }
}
