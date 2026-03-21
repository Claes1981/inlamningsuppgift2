using TodoApp.Domain.Entities;
using Xunit;
using FluentAssertions;
using System;

namespace TodoApp.Tests.Domain.Entities;

public class TodoTests
{
    [Fact]
    public void Ctor_WithValidData_CreatesTodo()
    {
        // Arrange & Act
        var todo = new Todo
        {
            Id = "1",
            Title = "Test Task",
            Description = "Test Description",
            IsCompleted = false,
            CreatedAt = DateTime.UtcNow
        };

        // Assert
        todo.Id.Should().Be("1");
        todo.Title.Should().Be("Test Task");
        todo.Description.Should().Be("Test Description");
        todo.IsCompleted.Should().BeFalse();
        todo.CreatedAt.Should().BeAfter(DateTime.MinValue);
    }

    [Fact]
    public void Ctor_WithEmptyTitle_StillCreatesTodo()
    {
        // Arrange & Act
        var todo = new Todo
        {
            Id = "1",
            Title = "",
            Description = "Test",
            IsCompleted = false,
            CreatedAt = DateTime.UtcNow
        };

        // Assert
        todo.Should().NotBeNull();
        todo.Title.Should().BeEmpty();
    }

    [Fact]
    public void Todo_WithCompletedTrue_HasCorrectState()
    {
        // Arrange & Act
        var todo = new Todo
        {
            Id = "1",
            Title = "Completed Task",
            Description = "Done",
            IsCompleted = true,
            CreatedAt = DateTime.UtcNow
        };

        // Assert
        todo.IsCompleted.Should().BeTrue();
    }

    [Fact]
    public void Todo_Id_IsUniqueIdentifier()
    {
        // Arrange
        var todo1 = new Todo { Id = "1", Title = "Task 1", Description = "Desc", IsCompleted = false, CreatedAt = DateTime.UtcNow };
        var todo2 = new Todo { Id = "2", Title = "Task 1", Description = "Desc", IsCompleted = false, CreatedAt = DateTime.UtcNow };

        // Act & Assert
        todo1.Id.Should().NotBe(todo2.Id);
        todo1.Should().NotBe(todo2);
    }

    [Fact]
    public void Todo_CreatedAt_IsImmutableAfterCreation()
    {
        // Arrange
        var createdAt = DateTime.UtcNow;
        var todo = new Todo
        {
            Id = "1",
            Title = "Task",
            Description = "Desc",
            IsCompleted = false,
            CreatedAt = createdAt
        };

        // Act
        todo.Title = "Updated Title";
        todo.IsCompleted = true;

        // Assert
        todo.CreatedAt.Should().Be(createdAt);
    }
}
