using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FluentAssertions;
using Moq;
using TodoApp.Application.DTOs;
using TodoApp.Application.Services;
using TodoApp.Domain.Entities;
using TodoApp.Domain.Repositories;
using Xunit;

namespace TodoApp.Tests.Application.Services;

public class TodoServiceTests
{
    private readonly Mock<ITodoRepository> _mockRepository;
    private readonly TodoService _service;

    public TodoServiceTests()
    {
        _mockRepository = new Mock<ITodoRepository>();
        _service = new TodoService(_mockRepository.Object);
    }

    #region GetTodosAsync

    [Fact]
    public async Task GetTodosAsync_WhenRepositoryReturnsTodos_ReturnsTodoDtos()
    {
        // Arrange
        var todos = new List<Todo>
        {
            new Todo("Task 1", "Desc 1"),
            new Todo("Task 2", "Desc 2")
        };
        _mockRepository.Setup(repo => repo.GetAllAsync()).ReturnsAsync(todos);

        // Act
        var result = await _service.GetTodosAsync();

        // Assert
        result.Should().HaveCount(2);
    }

    [Fact]
    public async Task GetTodosAsync_WhenRepositoryReturnsEmpty_ReturnsEmptyList()
    {
        // Arrange
        var todos = new List<Todo>();
        _mockRepository.Setup(repo => repo.GetAllAsync()).ReturnsAsync(todos);

        // Act
        var result = await _service.GetTodosAsync();

        // Assert
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetTodosAsync_WhenRepositoryReturnsNull_ReturnsEmptyList()
    {
        // Arrange
        _mockRepository.Setup(repo => repo.GetAllAsync()).ReturnsAsync((IEnumerable<Todo>)null!);

        // Act
        var result = await _service.GetTodosAsync();

        // Assert
        result.Should().BeEmpty();
    }

    #endregion

    #region GetTodoByIdAsync

    [Fact]
    public async Task GetTodoByIdAsync_WhenTodoExists_ReturnsTodoDto()
    {
        // Arrange
        var todo = new Todo("Task 1", "Desc 1");
        _mockRepository.Setup(repo => repo.GetByIdAsync(todo.Id)).ReturnsAsync(todo);

        // Act
        var result = await _service.GetTodoByIdAsync(todo.Id);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(todo.Id);
        result.Title.Should().Be("Task 1");
    }

    [Fact]
    public async Task GetTodoByIdAsync_WhenTodoDoesNotExist_ReturnsNull()
    {
        // Arrange
        _mockRepository.Setup(repo => repo.GetByIdAsync("nonexistent")).ReturnsAsync((Todo?)null);

        // Act
        var result = await _service.GetTodoByIdAsync("nonexistent");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetTodoByIdAsync_WithEmptyId_ReturnsNull()
    {
        // Act
        var result = await _service.GetTodoByIdAsync("");

        // Assert
        result.Should().BeNull();
        _mockRepository.Verify(repo => repo.GetByIdAsync(It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task GetTodoByIdAsync_WithNullId_ReturnsNull()
    {
        // Act
        var result = await _service.GetTodoByIdAsync(null!);

        // Assert
        result.Should().BeNull();
        _mockRepository.Verify(repo => repo.GetByIdAsync(It.IsAny<string>()), Times.Never);
    }

    #endregion

    #region CreateTodoAsync

    [Fact]
    public async Task CreateTodoAsync_WithValidDto_ReturnsCreatedTodoDto()
    {
        // Arrange
        var dto = new CreateTodoDto { Title = "New Task", Description = "New Description" };
        var createdTodo = new Todo("New Task", "New Description");
        _mockRepository.Setup(repo => repo.AddAsync(It.IsAny<Todo>())).ReturnsAsync(createdTodo);

        // Act
        var result = await _service.CreateTodoAsync(dto);

        // Assert
        result.Should().NotBeNull();
        result.Title.Should().Be("New Task");
        result.Description.Should().Be("New Description");
        result.IsCompleted.Should().BeFalse();
    }

    [Fact]
    public async Task CreateTodoAsync_WithNullDto_ThrowsArgumentNullException()
    {
        // Act
        var act = () => _service.CreateTodoAsync(null!);

        // Assert
        await act.Should().ThrowAsync<ArgumentNullException>()
            .WithMessage("*CreateTodoDto cannot be null*");
    }

    [Fact]
    public async Task CreateTodoAsync_WithEmptyTitle_ThrowsArgumentException()
    {
        // Arrange
        var dto = new CreateTodoDto { Title = "", Description = "Description" };

        // Act
        var act = () => _service.CreateTodoAsync(dto);

        // Assert
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*Title is required*");
    }

    [Fact]
    public async Task CreateTodoAsync_WithWhitespaceTitle_ThrowsArgumentException()
    {
        // Arrange
        var dto = new CreateTodoDto { Title = "   ", Description = "Description" };

        // Act
        var act = () => _service.CreateTodoAsync(dto);

        // Assert
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*Title is required*");
    }

    #endregion

    #region UpdateTodoAsync

    [Fact]
    public async Task UpdateTodoAsync_WithValidData_ReturnsUpdatedTodoDto()
    {
        // Arrange
        var existingTodo = new Todo("Old Title", "Old Desc");
        var dto = new UpdateTodoDto { Title = "New Title", Description = "New Desc", IsCompleted = true };
        
        _mockRepository.Setup(repo => repo.GetByIdAsync(existingTodo.Id)).ReturnsAsync(existingTodo);
        _mockRepository.Setup(repo => repo.UpdateAsync(It.IsAny<Todo>())).ReturnsAsync(existingTodo);

        // Act
        var result = await _service.UpdateTodoAsync(existingTodo.Id, dto);

        // Assert
        result.Should().NotBeNull();
        result.Title.Should().Be("New Title");
        result.IsCompleted.Should().BeTrue();
    }

    [Fact]
    public async Task UpdateTodoAsync_WhenTodoDoesNotExist_ThrowsKeyNotFoundException()
    {
        // Arrange
        _mockRepository.Setup(repo => repo.GetByIdAsync("nonexistent")).ReturnsAsync((Todo?)null);
        var dto = new UpdateTodoDto { Title = "New Title", Description = "New Desc", IsCompleted = false };

        // Act & Assert
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.UpdateTodoAsync("nonexistent", dto));
    }

    [Fact]
    public async Task UpdateTodoAsync_WithEmptyId_ThrowsArgumentException()
    {
        // Arrange
        var dto = new UpdateTodoDto { Title = "New Title" };

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(() => _service.UpdateTodoAsync("", dto));
    }

    [Fact]
    public async Task UpdateTodoAsync_WithNullDto_ThrowsArgumentNullException()
    {
        // Arrange
        var existingTodo = new Todo("Old Title");
        _mockRepository.Setup(repo => repo.GetByIdAsync(existingTodo.Id)).ReturnsAsync(existingTodo);

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentNullException>(() => _service.UpdateTodoAsync(existingTodo.Id, null!));
    }

    [Fact]
    public async Task UpdateTodoAsync_ChangesCompletionStatus_CallsMarkAsCompleted()
    {
        // Arrange
        var existingTodo = new Todo("Task");
        var dto = new UpdateTodoDto { Title = "Task", IsCompleted = true };
        
        _mockRepository.Setup(repo => repo.GetByIdAsync(existingTodo.Id)).ReturnsAsync(existingTodo);
        _mockRepository.Setup(repo => repo.UpdateAsync(It.IsAny<Todo>())).ReturnsAsync(existingTodo);

        // Act
        await _service.UpdateTodoAsync(existingTodo.Id, dto);

        // Assert
        _mockRepository.Verify(repo => repo.UpdateAsync(It.Is<Todo>(t => t.IsCompleted)), Times.Once);
    }

    #endregion

    #region DeleteTodoAsync

    [Fact]
    public async Task DeleteTodoAsync_WhenTodoExists_ReturnsTrue()
    {
        // Arrange
        _mockRepository.Setup(repo => repo.DeleteAsync("1")).ReturnsAsync(true);

        // Act
        var result = await _service.DeleteTodoAsync("1");

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task DeleteTodoAsync_WhenTodoDoesNotExist_ReturnsFalse()
    {
        // Arrange
        _mockRepository.Setup(repo => repo.DeleteAsync("nonexistent")).ReturnsAsync(false);

        // Act
        var result = await _service.DeleteTodoAsync("nonexistent");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task DeleteTodoAsync_WithEmptyId_ReturnsFalse()
    {
        // Act
        var result = await _service.DeleteTodoAsync("");

        // Assert
        result.Should().BeFalse();
        _mockRepository.Verify(repo => repo.DeleteAsync(It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task DeleteTodoAsync_WithNullId_ReturnsFalse()
    {
        // Act
        var result = await _service.DeleteTodoAsync(null!);

        // Assert
        result.Should().BeFalse();
        _mockRepository.Verify(repo => repo.DeleteAsync(It.IsAny<string>()), Times.Never);
    }

    #endregion
}
