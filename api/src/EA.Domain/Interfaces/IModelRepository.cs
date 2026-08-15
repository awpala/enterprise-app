using EA.Domain.Entities;
using EA.Domain.Enums;
using System.Text.Json;

namespace EA.Domain.Interfaces;

/// <summary>
/// Repository interface for model data access operations.
/// </summary>
public interface IModelRepository
{
    /// <summary>
    /// Retrieves a paged list of models, optionally filtered by status.
    /// </summary>
    /// <param name="page">The page number (1-based).</param>
    /// <param name="pageSize">The number of items per page.</param>
    /// <param name="status">Optional status filter.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A tuple of the items and total count.</returns>
    Task<(IReadOnlyList<Model> Items, int TotalCount)> GetModelsAsync(
        int page,
        int pageSize,
        ModelStatus? status,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a model by its unique identifier, including the latest run.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The model entity, or null if not found.</returns>
    Task<Model?> GetModelByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>
    /// Adds a new model entity to the data store.
    /// </summary>
    /// <param name="model">The model to add.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task AddModelAsync(Model model, CancellationToken cancellationToken = default);

    /// <summary>
    /// Updates an existing model entity.
    /// </summary>
    /// <param name="model">The model to update.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task UpdateModelAsync(Model model, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a model run by its unique identifier, including metrics.
    /// </summary>
    /// <param name="runId">The run identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The model run entity, or null if not found.</returns>
    Task<ModelRun?> GetModelRunByIdAsync(Guid runId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all runs for a given model.
    /// </summary>
    /// <param name="modelId">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A read-only list of model runs.</returns>
    Task<IReadOnlyList<ModelRun>> GetModelRunsAsync(Guid modelId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a paged list of all model runs across all models, optionally filtered by status.
    /// Includes the parent Model navigation property.
    /// </summary>
    /// <param name="page">The page number (1-based).</param>
    /// <param name="pageSize">The number of items per page.</param>
    /// <param name="status">Optional status filter.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A tuple of items (with Model included) and total count.</returns>
    Task<(IReadOnlyList<ModelRun> Items, int TotalCount)> GetAllRunsAsync(
        int page, int pageSize, ModelRunStatus? status, CancellationToken cancellationToken = default);

    /// <summary>
    /// Adds a new model run entity to the data store.
    /// </summary>
    /// <param name="run">The model run to add.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task AddModelRunAsync(ModelRun run, CancellationToken cancellationToken = default);

    /// <summary>
    /// Atomically records that a model run started without downgrading a terminal status.
    /// </summary>
    /// <param name="runId">The run identifier.</param>
    /// <param name="startedAtUtc">The worker-reported start timestamp.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True when the run exists.</returns>
    Task<bool> MarkModelRunStartedAsync(
        Guid runId,
        DateTime startedAtUtc,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Atomically records successful completion while preserving the earliest start timestamp.
    /// </summary>
    /// <param name="runId">The run identifier.</param>
    /// <param name="completedAtUtc">The worker-reported completion timestamp.</param>
    /// <param name="resultSummary">The computed result summary.</param>
    /// <param name="sampleData">The computed histogram data.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True when the run exists.</returns>
    Task<bool> MarkModelRunCompletedAsync(
        Guid runId,
        DateTime completedAtUtc,
        JsonDocument? resultSummary,
        JsonDocument? sampleData,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Atomically records failed completion while preserving the earliest start timestamp.
    /// </summary>
    /// <param name="runId">The run identifier.</param>
    /// <param name="completedAtUtc">The worker-reported failure timestamp.</param>
    /// <param name="errorMessage">The worker-reported error.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True when the run exists.</returns>
    Task<bool> MarkModelRunFailedAsync(
        Guid runId,
        DateTime completedAtUtc,
        string errorMessage,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Adds a collection of model metric entities to the data store.
    /// </summary>
    /// <param name="metrics">The metrics to add.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task AddModelMetricsAsync(IEnumerable<ModelMetric> metrics, CancellationToken cancellationToken = default);

    /// <summary>
    /// Saves all pending changes to the data store.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task SaveChangesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Checks whether a model with the given identifier exists and is not archived.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True if the model exists and is not archived.</returns>
    Task<bool> ModelExistsAsync(Guid id, CancellationToken cancellationToken = default);
}
