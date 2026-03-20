using Microsoft.AspNetCore.Mvc;
using TodoApp.Application.DTOs;
using TodoApp.Application.Services;

namespace TodoApp.Presentation.Controllers;

/// <summary>
/// MVC Controller for Todo CRUD operations.
/// Follows Single Responsibility Principle - handles HTTP requests and responses only.
/// </summary>
public class TodoController : Controller
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
    /// GET: /Todo - Displays the list of all todo items.
    /// </summary>
    public async Task<IActionResult> Index()
    {
        var todos = await _todoService.GetAllAsync();
        return View(todos);
    }

    /// <summary>
    /// GET: /Todo/Details/{id} - Displays details of a specific todo item.
    /// </summary>
    public async Task<IActionResult> Details(string id)
    {
        var todo = await _todoService.GetByIdAsync(id);
        if (todo == null)
        {
            return NotFound();
        }

        return View(todo);
    }

    /// <summary>
    /// GET: /Todo/Create - Displays the create todo form.
    /// </summary>
    public IActionResult Create()
    {
        return View();
    }

    /// <summary>
    /// POST: /Todo/Create - Creates a new todo item.
    /// </summary>
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(CreateTodoDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Title))
        {
            ModelState.AddModelError("Title", "Title is required");
        }

        if (!ModelState.IsValid)
        {
            return View(dto);
        }

        await _todoService.CreateAsync(dto);
        return RedirectToAction(nameof(Index));
    }

    /// <summary>
    /// GET: /Todo/Edit/{id} - Displays the edit todo form.
    /// </summary>
    public async Task<IActionResult> Edit(string id)
    {
        var todo = await _todoService.GetByIdAsync(id);
        if (todo == null)
        {
            return NotFound();
        }

        var dto = new UpdateTodoDto
        {
            Id = todo.Id,
            Title = todo.Title,
            Description = todo.Description,
            IsCompleted = todo.IsCompleted
        };

        return View(dto);
    }

    /// <summary>
    /// POST: /Todo/Edit/{id} - Updates an existing todo item.
    /// </summary>
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(string id, UpdateTodoDto dto)
    {
        if (id != dto.Id)
        {
            return BadRequest();
        }

        if (string.IsNullOrWhiteSpace(dto.Title))
        {
            ModelState.AddModelError("Title", "Title is required");
        }

        if (!ModelState.IsValid)
        {
            return View(dto);
        }

        try
        {
            await _todoService.UpdateAsync(id, dto);
            return RedirectToAction(nameof(Index));
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }

    /// <summary>
    /// GET: /Todo/Delete/{id} - Displays the delete confirmation page.
    /// </summary>
    public async Task<IActionResult> Delete(string id)
    {
        var todo = await _todoService.GetByIdAsync(id);
        if (todo == null)
        {
            return NotFound();
        }

        return View(todo);
    }

    /// <summary>
    /// POST: /Todo/Delete/{id} - Deletes a todo item.
    /// </summary>
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(string id)
    {
        try
        {
            await _todoService.DeleteAsync(id);
            return RedirectToAction(nameof(Index));
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }
}
