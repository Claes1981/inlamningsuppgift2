using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using MongoDB.Bson;
using MongoDB.Driver;
using TodoApp.Domain.Entities;
using TodoApp.Infrastructure.Repositories;
using Xunit;

namespace TodoApp.Tests.Infrastructure.Repositories;

public class MongoTodoRepositoryTests
{
    private readonly Mock<IMongoClient> _mockClient;
    private readonly Mock<IMongoDatabase> _mockDatabase;
    private readonly Mock<IMongoCollection<Todo>> _mockCollection;
    private readonly Mock<ILogger<MongoTodoRepository>> _mockLogger;

    public MongoTodoRepositoryTests()
    {
        _mockClient = new Mock<IMongoClient>();
        _mockDatabase = new Mock<IMongoDatabase>();
        _mockCollection = new Mock<IMongoCollection<Todo>>();
        _mockLogger = new Mock<ILogger<MongoTodoRepository>>();

        _mockClient.Setup(c => c.GetDatabase(It.IsAny<string>())).Returns(_mockDatabase.Object);
        _mockDatabase.Setup(db => db.GetCollection<Todo>(It.IsAny<string>())).Returns(_mockCollection.Object);
    }

    #region Constructor Tests

    [Fact]
    public void Ctor_WithValidParameters_CreatesRepository()
    {
        // Arrange & Act
        var repository = new MongoTodoRepository(
            _mockClient.Object,
            "TestDatabase",
            "todos",
            _mockLogger.Object);

        // Assert
        repository.Should().NotBeNull();
    }

    [Fact]
    public void Ctor_WithEmptyDatabaseName_ThrowsArgumentException()
    {
        // Act & Assert
        var act = () => new MongoTodoRepository(
            _mockClient.Object,
            "",
            "todos");
        
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Database name cannot be null or empty*");
    }

    [Fact]
    public void Ctor_WithNullDatabaseName_ThrowsArgumentException()
    {
        // Act & Assert
        var act = () => new MongoTodoRepository(
            _mockClient.Object,
            null!,
            "todos");
        
        act.Should().Throw<ArgumentException>()
            .WithMessage("*Database name cannot be null or empty*");
    }

    #endregion

    #region GetAllAsync

    [Fact(Skip = "Cannot mock MongoDB extension methods with Moq")]
    public async Task GetAllAsync_WhenCollectionHasDocuments_ReturnsTodos()
    {
    }

    [Fact(Skip = "Cannot mock MongoDB extension methods with Moq")]
    public async Task GetAllAsync_WhenCollectionIsEmpty_ReturnsEmptyList()
    {
    }

    #endregion

    #region GetByIdAsync

    [Fact(Skip = "Cannot mock MongoDB extension methods with Moq")]
    public async Task GetByIdAsync_WhenTodoExists_ReturnsTodo()
    {
    }

    [Fact(Skip = "Cannot mock MongoDB extension methods with Moq")]
    public async Task GetByIdAsync_WhenTodoDoesNotExist_ReturnsNull()
    {
    }

    [Fact]
    public async Task GetByIdAsync_WithEmptyId_ReturnsNull()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        // Act
        var result = await repository.GetByIdAsync("");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByIdAsync_WithNullId_ReturnsNull()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        // Act
        var result = await repository.GetByIdAsync(null!);

        // Assert
        result.Should().BeNull();
    }

    #endregion

    #region AddAsync

    [Fact]
    public async Task AddAsync_WithValidTodo_InsertsAndReturnsTodo()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);
        var todo = new Todo("New Task");

        _mockCollection.Setup(c => c.InsertOneAsync(
            It.Is<Todo>(t => t.Id == todo.Id),
            It.IsAny<InsertOneOptions>(),
            It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await repository.AddAsync(todo);

        // Assert
        result.Should().BeSameAs(todo);
        _mockCollection.Verify(c => c.InsertOneAsync(It.IsAny<Todo>(), It.IsAny<InsertOneOptions>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task AddAsync_WithNullTodo_ThrowsArgumentNullException()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentNullException>(() => repository.AddAsync(null!));
    }

    #endregion

    #region UpdateAsync

    [Fact]
    public async Task UpdateAsync_WhenTodoExists_UpdatesAndReturnsTodo()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);
        var todo = new Todo("Updated Task");

        var mockResult = new Mock<ReplaceOneResult>();
        mockResult.Setup(r => r.ModifiedCount).Returns(1L);

        _mockCollection.Setup(c => c.ReplaceOneAsync(
            It.IsAny<FilterDefinition<Todo>>(),
            It.Is<Todo>(t => t.Id == todo.Id)))
            .ReturnsAsync(mockResult.Object);

        // Act
        var result = await repository.UpdateAsync(todo);

        // Assert
        result.Should().BeSameAs(todo);
        _mockCollection.Verify(c => c.ReplaceOneAsync(It.IsAny<FilterDefinition<Todo>>(), It.IsAny<Todo>()), Times.Once);
    }

    [Fact]
    public async Task UpdateAsync_WhenTodoDoesNotExist_ThrowsKeyNotFoundException()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);
        var todo = new Todo("Task");

        var mockResult = new Mock<ReplaceOneResult>();
        mockResult.Setup(r => r.ModifiedCount).Returns(0L);

        _mockCollection.Setup(c => c.ReplaceOneAsync(
            It.IsAny<FilterDefinition<Todo>>(),
            It.IsAny<Todo>()))
            .ReturnsAsync(mockResult.Object);

        // Act & Assert
        await Assert.ThrowsAsync<KeyNotFoundException>(() => repository.UpdateAsync(todo));
    }

    [Fact]
    public async Task UpdateAsync_WithNullTodo_ThrowsArgumentNullException()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentNullException>(() => repository.UpdateAsync(null!));
    }

    #endregion

    #region DeleteAsync

    [Fact]
    public async Task DeleteAsync_WhenTodoExists_ReturnsTrue()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        var mockResult = new Mock<DeleteResult>();
        mockResult.Setup(r => r.DeletedCount).Returns(1L);

        _mockCollection.Setup(c => c.DeleteOneAsync(
            It.IsAny<FilterDefinition<Todo>>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResult.Object);

        // Act
        var result = await repository.DeleteAsync("1");

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task DeleteAsync_WhenTodoDoesNotExist_ReturnsFalse()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        var mockResult = new Mock<DeleteResult>();
        mockResult.Setup(r => r.DeletedCount).Returns(0L);

        _mockCollection.Setup(c => c.DeleteOneAsync(
            It.IsAny<FilterDefinition<Todo>>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResult.Object);

        // Act
        var result = await repository.DeleteAsync("nonexistent");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task DeleteAsync_WithEmptyId_ReturnsFalse()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        // Act
        var result = await repository.DeleteAsync("");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task DeleteAsync_WithNullId_ReturnsFalse()
    {
        // Arrange
        var repository = new MongoTodoRepository(_mockClient.Object, "TestDatabase", "todos", _mockLogger.Object);

        // Act
        var result = await repository.DeleteAsync(null!);

        // Assert
        result.Should().BeFalse();
    }

    #endregion
}
