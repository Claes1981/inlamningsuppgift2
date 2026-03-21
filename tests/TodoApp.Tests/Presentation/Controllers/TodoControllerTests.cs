using FluentAssertions;
using Xunit;
using Moq;
using TodoApp.Application.Services;
using TodoApp.Application.DTOs;
using TodoApp.Domain.Entities;
using TodoApp.Presentation.Controllers;
using Microsoft.AspNetCore.Mvc;

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

    [Fact]
    public async Task Index_ReturnsOkResultWithTodos()
    {
        // Arrange
        var todos = new List<TodoDto>
        {
            new TodoDto { Id = "1", Title = "Test", IsCompleted = false }
        };
        _mockService.Setup(s => s.GetTodosAsync()).ReturnsAsync(todos);

        // Act
        var result = await _controller.Index();

        // Assert
        var actionResult = result.Should().BeOfType<ActionResult<IEnumerable<TodoDto>>>()
            .Subject;
        actionResult.Value.Should().BeEquivalentTo(todos);
    }

    [Fact]
    public async Task Index_WithEmptyList_ReturnsOkResultWithEmptyList()
    {
        // Arrange
        _mockService.Setup(s => s.GetTodosAsync()).ReturnsAsync(new List<TodoDto>());

        // Act
        var result = await _controller.Index();

        // Assert
        var actionResult = result.Should().BeOfType<ActionResult<IEnumerable<TodoDto>>>()
            .Subject;
        actionResult.Value.Should().BeEmpty();
    }

    [Fact]
    public async Task Details_ReturnsOkResultWithTodo()
    {
        // Arrange
        var todo = new TodoDto { Id = "1", Title = "Test", IsCompleted = false };
        _mockService.Setup(s => s.GetTodoByIdAsync("1")).ReturnsAsync(todo);

        // Act
        var result = await _controller.Details("1");

        // Assert
        var actionResult = result.Should().BeOfType<ActionResult<TodoDto>>().Subject;
        actionResult.Result.Should().BeOfType<OkObjectResult>("found todo should return 200 Ok");
        var okResult = (OkObjectResult)actionResult.Result!;
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
        var actionResult = result.Should().BeOfType<ActionResult<TodoDto>>().Subject;
        actionResult.Result.Should().BeOfType<NotFoundResult>("non-existent todo should return 404 NotFound");
    }

    [Fact]
    public async Task Create_ReturnsCreatedAtActionResultWithCreatedTodo()
    {
        // Arrange
        var createDto = new CreateTodoDto { Title = "New Todo", Description = "Test" };
        var createdTodo = new TodoDto
        {
            Id = "1",
            Title = "New Todo",
            Description = "Test",
            IsCompleted = false
        };
        _mockService.Setup(s => s.CreateTodoAsync(createDto)).ReturnsAsync(createdTodo);

        // Act
        var result = await _controller.Create(createDto);

        // Assert
        result.Should().BeOfType<ActionResult<TodoDto>>();
        var actionResult = (ActionResult<TodoDto>)result;
        actionResult.Result.Should().BeOfType<CreatedAtActionResult>("created todo should return 201 Created");
    }

    [Fact]
    public async Task Update_ReturnsOkResultWithUpdatedTodo()
    {
        // Arrange
        var updateDto = new UpdateTodoDto { Title = "Updated Todo", IsCompleted = true };
        var updatedTodo = new TodoDto
        {
            Id = "1",
            Title = "Updated Todo",
            IsCompleted = true
        };
        _mockService.Setup(s => s.UpdateTodoAsync("1", updateDto)).ReturnsAsync(updatedTodo);

        // Act
        var result = await _controller.Update("1", updateDto);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
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
    public async Task Delete_ReturnsNoContentWhenDeleted()
    {
        // Arrange
        _mockService.Setup(s => s.DeleteTodoAsync("1")).ReturnsAsync(true);

        // Act
        var result = await _controller.Delete("1");

        // Assert
        result.Should().BeOfType<NoContentResult>("successful delete should return 204 NoContent");
    }

    [Fact]
    public async Task Delete_ReturnsNotFoundWhenNotDeleted()
    {
        // Arrange
        _mockService.Setup(s => s.DeleteTodoAsync("nonexistent")).ReturnsAsync(false);

        // Act
        var result = await _controller.Delete("nonexistent");

        // Assert
        result.Should().BeOfType<NotFoundResult>("delete of non-existent todo should return 404 NotFound");
    }
}
