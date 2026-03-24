namespace TodoApp.Application.Common;

/// <summary>
/// Represents the result of an operation that may succeed or fail.
/// Follows the Result Pattern for better error handling without exceptions.
/// </summary>
/// <typeparam name="T">The type of the result value.</typeparam>
public class Result<T>
{
    /// <summary>
    /// Indicates whether the operation succeeded.
    /// </summary>
    public bool IsSuccess { get; private set; }

    /// <summary>
    /// The result value if the operation succeeded.
    /// </summary>
    public T? Value { get; private set; }

    /// <summary>
    /// Error message if the operation failed.
    /// </summary>
    public string? Error { get; private set; }

    /// <summary>
    /// Creates a successful result.
    /// </summary>
    private Result(T value)
    {
        IsSuccess = true;
        Value = value;
    }

    /// <summary>
    /// Creates a failed result.
    /// </summary>
    private Result(string error)
    {
        IsSuccess = false;
        Error = error;
    }

    /// <summary>
    /// Creates a successful result with the given value.
    /// </summary>
    public static Result<T> Success(T value) => new(value);

    /// <summary>
    /// Creates a failed result with the given error message.
    /// </summary>
    public static Result<T> Failure(string error) => new(error);

    /// <summary>
    /// Unwrap the result, throwing an exception if failed.
    /// </summary>
    public T GetValue()
    {
        if (!IsSuccess)
        {
            throw new InvalidOperationException(Error);
        }

        return Value!;
    }
}

/// <summary>
/// Represents the result of an operation that doesn't return a value.
/// </summary>
public class Result
{
    /// <summary>
    /// Indicates whether the operation succeeded.
    /// </summary>
    public bool IsSuccess { get; private set; }

    /// <summary>
    /// Error message if the operation failed.
    /// </summary>
    public string? Error { get; private set; }

    /// <summary>
    /// Creates a successful result.
    /// </summary>
    private Result()
    {
        IsSuccess = true;
    }

    /// <summary>
    /// Creates a failed result.
    /// </summary>
    private Result(string error)
    {
        IsSuccess = false;
        Error = error;
    }

    /// <summary>
    /// Creates a successful result.
    /// </summary>
    public static Result Success() => new();

    /// <summary>
    /// Creates a failed result with the given error message.
    /// </summary>
    public static Result Failure(string error) => new(error);
}
