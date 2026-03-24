using Microsoft.AspNetCore.Mvc;
using TodoApp.Application.DTOs;
using TodoApp.Application.Services;

namespace TodoApp.Presentation.Controllers;

/// <summary>
/// REST API Controller for Todo CRUD operations.
/// Follows Single Responsibility Principle - handles HTTP request/response translation.
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
    /// <returns>List of all todo items.</returns>
    /// <response code="200">Returns the list of todos.</response>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<TodoDto>>> Index()
    {
        var todos = await _todoService.GetTodosAsync();
        return Ok(todos ?? Enumerable.Empty<TodoDto>());
    }

    /// <summary>
    /// GET: /api/todo/{id} - Gets a specific todo item by ID.
    /// </summary>
    /// <param name="id">The unique identifier of the todo item.</param>
    /// <returns>The todo item.</returns>
    /// <response code="200">Returns the todo item.</response>
    /// <response code="404">Todo not found.</response>
    [HttpGet("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
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
    /// <param name="dto">The todo data to create.</param>
    /// <returns>The created todo item.</returns>
    /// <response code="201">Returns the created todo.</response>
    /// <response code="400">Invalid request data.</response>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
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
    /// <param name="id">The unique identifier of the todo item.</param>
    /// <param name="dto">The updated todo data.</param>
    /// <returns>The updated todo item.</returns>
    /// <response code="200">Returns the updated todo.</response>
    /// <response code="400">Invalid request data.</response>
    /// <response code="404">Todo not found.</response>
    [HttpPut("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
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
    /// <param name="id">The unique identifier of the todo item.</param>
    /// <returns>No content if successful.</returns>
    /// <response code="204">Todo deleted successfully.</response>
    /// <response code="404">Todo not found.</response>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
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
