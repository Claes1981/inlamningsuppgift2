using System.ComponentModel.DataAnnotations;

namespace TodoApp.Application.DTOs;

/// <summary>
/// Data Transfer Object for updating an existing Todo.
/// Contains all fields that can be modified with validation attributes.
/// </summary>
public class UpdateTodoDto
{
    /// <summary>
    /// The unique identifier of the todo item.
    /// Used for form binding but not required for validation.
    /// </summary>
    public string? Id { get; set; }

    /// <summary>
    /// Title of the todo item. Required, cannot be empty, max 200 characters.
    /// </summary>
    [Required(ErrorMessage = "Title is required.")]
    [StringLength(200, ErrorMessage = "Title cannot exceed 200 characters.")]
    [MinLength(1, ErrorMessage = "Title cannot be empty.")]
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// Description of the todo item. Optional, max 1000 characters.
    /// </summary>
    [StringLength(1000, ErrorMessage = "Description cannot exceed 1000 characters.")]
    public string? Description { get; set; }

    /// <summary>
    /// Indicates whether the todo item is completed.
    /// </summary>
    public bool IsCompleted { get; set; }

    /// <summary>
    /// Category for the todo item. Used as shard key in Cosmos DB. Optional.
    /// </summary>
    [StringLength(50, ErrorMessage = "Category cannot exceed 50 characters.")]
    public string? Category { get; set; }
}
