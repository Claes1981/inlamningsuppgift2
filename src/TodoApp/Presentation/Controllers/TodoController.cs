using Microsoft.AspNetCore.Mvc;
using TodoApp.Application.DTOs;
using TodoApp.Application.Services;

namespace TodoApp.Presentation.Controllers;

/// <summary>
/// Controller for Todo CRUD operations.
/// Follows Single Responsibility Principle - handles HTTP requests for Todo operations.
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
    /// GET: /api/todo - Gets all todo items.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<TodoDto>>> Index()
    {
        var todos = await _todoService.GetTodosAsync();
        return Ok(todos);
    }

    /// <summary>
    /// GET: /api/todo/{id} - Gets a specific todo item by ID.
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<TodoDto>> Details(string id)
    {
        var todo = await _todoService.GetTodoByIdAsync(id);
        if (todo == null)
        {
            return NotFound();
        }
        return Ok(todo);
    }

    /// <summary>
    /// POST: /api/todo - Creates a new todo item.
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<TodoDto>> Create([FromBody] CreateTodoDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var createdTodo = await _todoService.CreateTodoAsync(dto);
        return CreatedAtAction(nameof(Details), new { id = createdTodo.Id }, createdTodo);
    }

    /// <summary>
    /// PUT: /api/todo/{id} - Updates an existing todo item.
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] UpdateTodoDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var updatedTodo = await _todoService.UpdateTodoAsync(id, dto);
            return Ok(updatedTodo);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }

    /// <summary>
    /// DELETE: /api/todo/{id} - Deletes a todo item.
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        try
        {
            var result = await _todoService.DeleteTodoAsync(id);
            if (!result)
            {
                return NotFound();
            }
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }
}
