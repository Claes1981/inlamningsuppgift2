using TodoApp.Application.DTOs;
using TodoApp.Application.Services;
using TodoApp.Domain.Entities;
using TodoApp.Domain.Repositories;
using Moq;
using Xunit;
using FluentAssertions;
using System.Collections.Generic;
using System.Threading.Tasks;
using System;

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
            new Todo { Id = "1", Title = "Task 1", Description = "Desc 1", IsCompleted = false, CreatedAt = DateTime.UtcNow },
            new Todo { Id = "2", Title = "Task 2", Description = "Desc 2", IsCompleted = true, CreatedAt = DateTime.UtcNow }
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

    #endregion

    #region GetTodoByIdAsync

    [Fact]
    public async Task GetTodoByIdAsync_WhenTodoExists_ReturnsTodoDto()
    {
        // Arrange
        var todo = new Todo { Id = "1", Title = "Task 1", Description = "Desc 1", IsCompleted = false, CreatedAt = DateTime.UtcNow };
        _mockRepository.Setup(repo => repo.GetByIdAsync("1")).ReturnsAsync(todo);

        // Act
        var result = await _service.GetTodoByIdAsync("1");

        // Assert
        result.Should().NotBeNull();
        result.Id.Should().Be("1");
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

    #endregion

    #region CreateTodoAsync

    [Fact]
    public async Task CreateTodoAsync_WithValidDto_ReturnsCreatedTodoDto()
    {
        // Arrange
        var dto = new CreateTodoDto { Title = "New Task", Description = "New Description" };
        var createdTodo = new Todo { Id = "1", Title = "New Task", Description = "New Description", IsCompleted = false, CreatedAt = DateTime.UtcNow };
        _mockRepository.Setup(repo => repo.AddAsync(It.IsAny<Todo>())).ReturnsAsync(createdTodo);

        // Act
        var result = await _service.CreateTodoAsync(dto);

        // Assert
        result.Should().NotBeNull();
        result.Title.Should().Be("New Task");
        result.Description.Should().Be("New Description");
        result.IsCompleted.Should().BeFalse();
    }

    #endregion

    #region UpdateTodoAsync

    [Fact]
    public async Task UpdateTodoAsync_WithValidData_ReturnsUpdatedTodoDto()
    {
        // Arrange
        var existingTodo = new Todo { Id = "1", Title = "Old Title", Description = "Old Desc", IsCompleted = false, CreatedAt = DateTime.UtcNow };
        var dto = new UpdateTodoDto { Title = "New Title", Description = "New Desc", IsCompleted = true };
        
        _mockRepository.Setup(repo => repo.GetByIdAsync("1")).ReturnsAsync(existingTodo);
        _mockRepository.Setup(repo => repo.UpdateAsync(It.IsAny<Todo>())).ReturnsAsync(existingTodo);

        // Act
        var result = await _service.UpdateTodoAsync("1", dto);

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

    #endregion
}
