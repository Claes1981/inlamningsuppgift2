using Microsoft.AspNetCore.Mvc;
using TodoApp.Application.DTOs;
using TodoApp.Application.Services;

namespace TodoApp.Presentation.Controllers;

/// <summary>
/// MVC Controller for Todo CRUD operations.
/// Follows Single Responsibility Principle - handles HTTP requests and responses only.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class TodoController : ControllerBase
{
    private readonly ITodoService _todoService;

    /// <summary>
    /// Constructor injection for dependency inversion.
    /// </summary>
    /// <param name="todoService">The todo service implementation.</param>
    public TodoController(ITodoService todoService)
    {
        _todoService = todoService;
    }

    /// <summary>
    /// GET: api/todo - Gets all todo items.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<TodoDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<TodoDto>>> GetAll()
    {
        var todos = await _todoService.GetAllAsync();
        return Ok(todos);
    }

    /// <summary>
    /// GET: api/todo/{id} - Gets a todo item by ID.
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(TodoDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TodoDto>> GetById(string id)
    {
        var todo = await _todoService.GetByIdAsync(id);
        if (todo == null)
        {
            return NotFound();
        }

        return Ok(todo);
    }

    /// <summary>
    /// POST: api/todo - Creates a new todo item.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(TodoDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<TodoDto>> Create([FromBody] CreateTodoDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Title))
        {
            return BadRequest(new { error = "Title is required" });
        }

        var todo = await _todoService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = todo.Id }, todo);
    }

    /// <summary>
    /// PUT: api/todo/{id} - Updates an existing todo item.
    /// </summary>
    [HttpPut("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Update(string id, [FromBody] UpdateTodoDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Title))
        {
            return BadRequest(new { error = "Title is required" });
        }

        try
        {
            var todo = await _todoService.UpdateAsync(id, dto);
            return Ok(todo);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }

    /// <summary>
    /// DELETE: api/todo/{id} - Deletes a todo item.
    /// </summary>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Delete(string id)
    {
        var deleted = await _todoService.DeleteAsync(id);
        if (!deleted)
        {
            return NotFound();
        }

        return Ok();
    }
}
