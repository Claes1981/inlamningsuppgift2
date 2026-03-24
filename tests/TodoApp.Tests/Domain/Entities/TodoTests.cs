using System;
using FluentAssertions;
using TodoApp.Domain.Entities;
using Xunit;

namespace TodoApp.Tests.Domain.Entities;

public class TodoTests
{
    #region Constructor Tests

    [Fact]
    public void Ctor_WithValidData_CreatesTodo()
    {
        // Arrange & Act
        var todo = new Todo("Test Task", "Test Description");

        // Assert
        todo.Id.Should().NotBeEmpty();
        todo.Title.Should().Be("Test Task");
        todo.Description.Should().Be("Test Description");
        todo.IsCompleted.Should().BeFalse();
        todo.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        todo.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void Ctor_WithValidDataAndNoDescription_CreatesTodo()
    {
        // Arrange & Act
        var todo = new Todo("Test Task");

        // Assert
        todo.Id.Should().NotBeEmpty();
        todo.Title.Should().Be("Test Task");
        todo.Description.Should().BeNull();
        todo.IsCompleted.Should().BeFalse();
    }

    [Fact]
    public void Ctor_WithTitleWithWhitespace_TrimsTitle()
    {
        // Arrange & Act
        var todo = new Todo("  Test Task  ", "  Description  ");

        // Assert
        todo.Title.Should().Be("Test Task");
        todo.Description.Should().Be("Description");
    }

    [Fact]
    public void Ctor_WithEmptyTitle_ThrowsArgumentException()
    {
        // Act & Assert
        var act = () => new Todo("");
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Title cannot be empty*");
    }

    [Fact]
    public void Ctor_WithWhitespaceTitle_ThrowsArgumentException()
    {
        // Act & Assert
        var act = () => new Todo("   ");
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Title cannot be empty*");
    }

    [Fact]
    public void Ctor_WithTitleExceedingMaxLength_ThrowsArgumentException()
    {
        // Arrange
        var longTitle = new string('a', 201);

        // Act & Assert
        var act = () => new Todo(longTitle);
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Title cannot exceed 200 characters*");
    }

    [Fact]
    public void Ctor_WithDescriptionExceedingMaxLength_ThrowsArgumentException()
    {
        // Arrange
        var longDescription = new string('a', 1001);

        // Act & Assert
        var act = () => new Todo("Test", longDescription);
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Description cannot exceed 1000 characters*");
    }

    #endregion

    #region Property Tests

    [Fact]
    public void Todo_Id_IsUniqueIdentifier()
    {
        // Arrange & Act
        var todo1 = new Todo("Task 1");
        var todo2 = new Todo("Task 2");

        // Assert
        todo1.Id.Should().NotBe(todo2.Id);
        todo1.Id.Should().NotBeEmpty();
        todo2.Id.Should().NotBeEmpty();
    }

    [Fact]
    public void Todo_CreatedAt_IsSetOnCreation()
    {
        // Arrange & Act
        var todo = new Todo("Test");

        // Assert
        todo.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void Todo_UpdatedAt_IsSetOnCreation()
    {
        // Arrange & Act
        var todo = new Todo("Test");

        // Assert
        todo.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void Todo_IsCompleted_DefaultsToFalse()
    {
        // Arrange & Act
        var todo = new Todo("Test");

        // Assert
        todo.IsCompleted.Should().BeFalse();
    }

    #endregion

    #region Method Tests - MarkAsCompleted

    [Fact]
    public void MarkAsCompleted_SetsIsCompletedToTrue()
    {
        // Arrange
        var todo = new Todo("Test");
        todo.IsCompleted.Should().BeFalse();

        // Act
        todo.MarkAsCompleted();

        // Assert
        todo.IsCompleted.Should().BeTrue();
    }

    [Fact]
    public void MarkAsCompleted_UpdatesUpdatedAt()
    {
        // Arrange
        var todo = new Todo("Test");
        var originalUpdatedAt = todo.UpdatedAt;
        
        // Small delay to ensure time difference
        System.Threading.Thread.Sleep(10);

        // Act
        todo.MarkAsCompleted();

        // Assert
        todo.UpdatedAt.Should().BeAfter(originalUpdatedAt);
    }

    [Fact]
    public void MarkAsCompleted_WhenAlreadyCompleted_RemainsCompleted()
    {
        // Arrange
        var todo = new Todo("Test");
        todo.MarkAsCompleted();

        // Act
        todo.MarkAsCompleted();

        // Assert
        todo.IsCompleted.Should().BeTrue();
    }

    #endregion

    #region Method Tests - MarkAsNotCompleted

    [Fact]
    public void MarkAsNotCompleted_SetsIsCompletedToFalse()
    {
        // Arrange
        var todo = new Todo("Test");
        todo.MarkAsCompleted();
        todo.IsCompleted.Should().BeTrue();

        // Act
        todo.MarkAsNotCompleted();

        // Assert
        todo.IsCompleted.Should().BeFalse();
    }

    [Fact]
    public void MarkAsNotCompleted_UpdatesUpdatedAt()
    {
        // Arrange
        var todo = new Todo("Test");
        todo.MarkAsCompleted();
        var originalUpdatedAt = todo.UpdatedAt;
        
        // Small delay to ensure time difference
        System.Threading.Thread.Sleep(10);

        // Act
        todo.MarkAsNotCompleted();

        // Assert
        todo.UpdatedAt.Should().BeAfter(originalUpdatedAt);
    }

    #endregion

    #region Method Tests - Update

    [Fact]
    public void Update_UpdatesTitleAndDescription()
    {
        // Arrange
        var todo = new Todo("Original Title", "Original Description");

        // Act
        todo.Update("New Title", "New Description");

        // Assert
        todo.Title.Should().Be("New Title");
        todo.Description.Should().Be("New Description");
    }

    [Fact]
    public void Update_UpdatesTitleAndSetsDescriptionToNull()
    {
        // Arrange
        var todo = new Todo("Original Title", "Original Description");

        // Act
        todo.Update("New Title", null);

        // Assert
        todo.Title.Should().Be("New Title");
        todo.Description.Should().BeNull();
    }

    [Fact]
    public void Update_UpdatesTitleWithWhitespace_TrimsTitle()
    {
        // Arrange
        var todo = new Todo("Original", "Original");

        // Act
        todo.Update("  New Title  ", "  New Description  ");

        // Assert
        todo.Title.Should().Be("New Title");
        todo.Description.Should().Be("New Description");
    }

    [Fact]
    public void Update_UpdatesUpdatedAt()
    {
        // Arrange
        var todo = new Todo("Test");
        var originalUpdatedAt = todo.UpdatedAt;
        
        // Small delay to ensure time difference
        System.Threading.Thread.Sleep(10);

        // Act
        todo.Update("New Title", "New Description");

        // Assert
        todo.UpdatedAt.Should().BeAfter(originalUpdatedAt);
    }

    [Fact]
    public void Update_WithEmptyTitle_ThrowsArgumentException()
    {
        // Arrange
        var todo = new Todo("Original");

        // Act & Assert
        var act = () => todo.Update("", "Description");
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Title cannot be empty*");
    }

    [Fact]
    public void Update_WithTitleExceedingMaxLength_ThrowsArgumentException()
    {
        // Arrange
        var todo = new Todo("Original");
        var longTitle = new string('a', 201);

        // Act & Assert
        var act = () => todo.Update(longTitle, "Description");
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Title cannot exceed 200 characters*");
    }

    [Fact]
    public void Update_WithDescriptionExceedingMaxLength_ThrowsArgumentException()
    {
        // Arrange
        var todo = new Todo("Original");
        var longDescription = new string('a', 1001);

        // Act & Assert
        var act = () => todo.Update("New Title", longDescription);
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Description cannot exceed 1000 characters*");
    }

    #endregion

    #region Immutability Tests

    [Fact]
    public void CreatedAt_IsImmutableAfterCreation()
    {
        // Arrange
        var createdAt = DateTime.UtcNow;
        var todo = new Todo("Test");
        var originalCreatedAt = todo.CreatedAt;

        // Act
        todo.Update("New Title", "New Description");
        todo.MarkAsCompleted();

        // Assert
        todo.CreatedAt.Should().Be(originalCreatedAt);
    }

    #endregion
}
