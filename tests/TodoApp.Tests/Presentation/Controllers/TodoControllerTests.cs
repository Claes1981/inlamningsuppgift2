using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Moq;
using TodoApp.Application.DTOs;
using TodoApp.Application.Services;
using TodoApp.Presentation.Controllers;
using Xunit;

namespace TodoApp.Tests.Presentation.Controllers;

public class TodoControllerTests
{
    private readonly Mock<ITodoService> _mockService;
    private readonly TodoController _controller;

    public TodoControllerTests()
    {
        _mockService = new Mock<ITodoService>();
        _controller = new TodoController(_mockService.Object);
    }

    #region Index (GET /api/todo)

    [Fact]
    public async Task Index_ReturnsOkResultWithTodos()
    {
        // Arrange
        var todos = new List<TodoDto>
        {
            new TodoDto { Id = "1", Title = "Test 1", IsCompleted = false, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new TodoDto { Id = "2", Title = "Test 2", IsCompleted = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }
        };
        _mockService.Setup(s => s.GetTodosAsync()).ReturnsAsync(todos);

        // Act
        var result = await _controller.Index();

        // Assert
        var okResult = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var returnedTodos = (List<TodoDto>)okResult.Value!;
        returnedTodos.Should().HaveCount(2);
    }

    [Fact]
    public async Task Index_WithEmptyList_ReturnsOkResultWithEmptyList()
    {
        // Arrange
        _mockService.Setup(s => s.GetTodosAsync()).ReturnsAsync(new List<TodoDto>());

        // Act
        var result = await _controller.Index();

        // Assert
        var okResult = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        ((List<TodoDto>)okResult.Value!).Should().BeEmpty();
    }

    [Fact]
    public async Task Index_WithNull_ReturnsOkResultWithEmptyList()
    {
        // Arrange
        _mockService.Setup(s => s.GetTodosAsync()).ReturnsAsync((IEnumerable<TodoDto>)null!);

        // Act
        var result = await _controller.Index();

        // Assert
        var okResult = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        ((IEnumerable<TodoDto>)okResult.Value!).Should().BeEmpty();
    }

    #endregion

    #region Details (GET /api/todo/{id})

    [Fact]
    public async Task Details_ReturnsOkResultWithTodo()
    {
        // Arrange
        var todo = new TodoDto 
        { 
            Id = "1", 
            Title = "Test", 
            IsCompleted = false, 
            CreatedAt = DateTime.UtcNow, 
            UpdatedAt = DateTime.UtcNow 
        };
        _mockService.Setup(s => s.GetTodoByIdAsync("1")).ReturnsAsync(todo);

        // Act
        var result = await _controller.Details("1");

        // Assert
        var okResult = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        okResult.StatusCode.Should().Be(200);
        okResult.Value.Should().BeEquivalentTo(todo);
    }

    [Fact]
    public async Task Details_WithNonExistentId_ReturnsNotFound()
    {
        // Arrange
        _mockService.Setup(s => s.GetTodoByIdAsync("nonexistent")).ReturnsAsync((TodoDto?)null);

        // Act
        var result = await _controller.Details("nonexistent");

        // Assert
        result.Result.Should().BeOfType<NotFoundResult>();
    }

    #endregion

    #region Create (POST /api/todo)

    [Fact]
    public async Task Create_WithValidDto_ReturnsCreatedAtActionResult()
    {
        // Arrange
        var createDto = new CreateTodoDto { Title = "New Todo", Description = "Test Description" };
        var createdTodo = new TodoDto
        {
            Id = "1",
            Title = "New Todo",
            Description = "Test Description",
            IsCompleted = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _mockService.Setup(s => s.CreateTodoAsync(createDto)).ReturnsAsync(createdTodo);

        // Act
        var result = await _controller.Create(createDto);

        // Assert
        var createdResult = result.Result.Should().BeOfType<CreatedAtActionResult>().Subject;
        createdResult.StatusCode.Should().Be(201);
        createdResult.Value.Should().BeEquivalentTo(createdTodo);
    }

    [Fact]
    public async Task Create_WithInvalidModelState_ReturnsBadRequest()
    {
        // Arrange
        var createDto = new CreateTodoDto { Title = "New Todo" };
        _controller.ModelState.AddModelError("Title", "Title is required.");

        // Act
        var result = await _controller.Create(createDto);

        // Assert
        result.Should().BeOfType<ActionResult<TodoDto>>();
        result.Result.Should().BeOfType<BadRequestObjectResult>();
    }

    #endregion

    #region Update (PUT /api/todo/{id})

    [Fact]
    public async Task Update_WithValidData_ReturnsOkResult()
    {
        // Arrange
        var updateDto = new UpdateTodoDto { Title = "Updated Todo", Description = "Updated", IsCompleted = true };
        var updatedTodo = new TodoDto
        {
            Id = "1",
            Title = "Updated Todo",
            Description = "Updated",
            IsCompleted = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _mockService.Setup(s => s.UpdateTodoAsync("1", updateDto)).ReturnsAsync(updatedTodo);

        // Act
        var result = await _controller.Update("1", updateDto);

        // Assert
        var okResult = result.Should().BeOfType<OkObjectResult>().Subject;
        okResult.StatusCode.Should().Be(200);
    }

    [Fact]
    public async Task Update_WithNonExistentId_ReturnsNotFound()
    {
        // Arrange
        var updateDto = new UpdateTodoDto { Title = "Updated", IsCompleted = false };
        _mockService.Setup(s => s.UpdateTodoAsync("nonexistent", updateDto))
            .Throws(new KeyNotFoundException());

        // Act
        var result = await _controller.Update("nonexistent", updateDto);

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task Update_WithInvalidModelState_ReturnsBadRequest()
    {
        // Arrange
        var updateDto = new UpdateTodoDto { Title = "Updated" };
        _controller.ModelState.AddModelError("Title", "Title is required.");

        // Act
        var result = await _controller.Update("1", updateDto);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
    }

    #endregion

    #region Delete (DELETE /api/todo/{id})

    [Fact]
    public async Task Delete_WhenTodoExists_ReturnsNoContent()
    {
        // Arrange
        _mockService.Setup(s => s.DeleteTodoAsync("1")).ReturnsAsync(true);

        // Act
        var result = await _controller.Delete("1");

        // Assert
        var noContentResult = result.Should().BeOfType<NoContentResult>().Subject;
        noContentResult.StatusCode.Should().Be(204);
    }

    [Fact]
    public async Task Delete_WhenTodoDoesNotExist_ReturnsNotFound()
    {
        // Arrange
        _mockService.Setup(s => s.DeleteTodoAsync("nonexistent")).ReturnsAsync(false);

        // Act
        var result = await _controller.Delete("nonexistent");

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task Delete_WhenKeyNotFoundException_ReturnsNotFound()
    {
        // Arrange
        _mockService.Setup(s => s.DeleteTodoAsync("nonexistent"))
            .Throws(new KeyNotFoundException());

        // Act
        var result = await _controller.Delete("nonexistent");

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    #endregion
}
