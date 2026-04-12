using EA.Domain.Entities;
using EA.Domain.Enums;

namespace EA.Domain.Interfaces;

/// <summary>
/// Facade interface encapsulating model business logic.
/// Controllers delegate to the facade; the facade orchestrates repositories and messaging.
/// </summary>
public interface IModelFacade
{
    /// <summary>
    /// Retrieves a paged list of models, optionally filtered by status.
    /// </summary>
    /// <param name="page">The page number (1-based).</param>
    /// <param name="pageSize">The number of items per page.</param>
    /// <param name="status">Optional status filter.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A tuple of items and total count.</returns>
    Task<(IReadOnlyList<Model> Items, int TotalCount)> GetModelsAsync(
        int page,
        int pageSize,
        ModelStatus? status,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a model by its unique identifier.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The model entity, or null if not found.</returns>
    Task<Model?> GetModelByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>
    /// Creates a new model with the specified properties.
    /// </summary>
    /// <param name="name">The model name.</param>
    /// <param name="description">Optional description.</param>
    /// <param name="parameters">Optional JSON parameters.</param>
    /// <param name="createdBy">The creator's identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The newly created model entity.</returns>
    Task<Model> CreateModelAsync(
        string name,
        string? description,
        System.Text.Json.JsonDocument? parameters,
        string createdBy,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Updates an existing model's mutable properties and increments its version.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="name">The updated name.</param>
    /// <param name="description">The updated description.</param>
    /// <param name="status">The updated status.</param>
    /// <param name="parameters">The updated JSON parameters.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The updated model entity, or null if not found.</returns>
    Task<Model?> UpdateModelAsync(
        Guid id,
        string name,
        string? description,
        ModelStatus status,
        System.Text.Json.JsonDocument? parameters,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Soft-deletes a model by setting its status to Archived.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True if the model was found and archived; false otherwise.</returns>
    Task<bool> ArchiveModelAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>
    /// Requests a new run for the specified model, publishing a message to the broker.
    /// </summary>
    /// <param name="modelId">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The newly created model run entity, or null if the model was not found.</returns>
    Task<ModelRun?> RequestModelRunAsync(Guid modelId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all runs for a given model.
    /// </summary>
    /// <param name="modelId">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A read-only list of model runs.</returns>
    Task<IReadOnlyList<ModelRun>> GetModelRunsAsync(Guid modelId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a specific model run by its identifier, including metrics.
    /// </summary>
    /// <param name="modelId">The parent model identifier (for validation).</param>
    /// <param name="runId">The run identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The model run entity, or null if not found or mismatched.</returns>
    Task<ModelRun?> GetModelRunByIdAsync(Guid modelId, Guid runId, CancellationToken cancellationToken = default);
}
