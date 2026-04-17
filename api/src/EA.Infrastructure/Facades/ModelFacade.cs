using System.Diagnostics;
using System.Text.Json;
using EA.Contracts.Messages;
using EA.Domain.Entities;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using MassTransit;
using Microsoft.Extensions.Logging;

namespace EA.Infrastructure.Facades;

/// <summary>
/// Facade implementation encapsulating model business logic.
/// Orchestrates data access via <see cref="IModelRepository"/> and messaging via MassTransit.
/// </summary>
public class ModelFacade(
    IModelRepository repository,
    IPublishEndpoint publishEndpoint,
    ILogger<ModelFacade> logger) : IModelFacade
{
    private static readonly ActivitySource ActivitySource = new("EA.Api.Facade");

    /// <summary>
    /// The set of distribution types supported by the data engine.
    /// </summary>
    private static readonly HashSet<string> SupportedDistributions = new(StringComparer.OrdinalIgnoreCase)
    {
        "normal", "uniform", "exponential", "lognormal"
    };

    /// <summary>
    /// Maximum degree of parallelism for batch run requests.
    /// </summary>
    private const int BatchMaxConcurrency = 5;

    /// <inheritdoc />
    public async Task<(IReadOnlyList<Model> Items, int TotalCount)> GetModelsAsync(
        int page,
        int pageSize,
        ModelStatus? status,
        CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(GetModelsAsync));

        ArgumentOutOfRangeException.ThrowIfLessThan(page, 1);
        ArgumentOutOfRangeException.ThrowIfLessThan(pageSize, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(pageSize, 100);

        logger.LogInformation("Retrieving models page {Page} with page size {PageSize}, status filter: {Status}",
            page, pageSize, status);

        return await repository.GetModelsAsync(page, pageSize, status, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<Model?> GetModelByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(GetModelByIdAsync));

        ArgumentOutOfRangeException.ThrowIfEqual(id, Guid.Empty);

        logger.LogInformation("Retrieving model {ModelId}", id);

        return await repository.GetModelByIdAsync(id, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<Model> CreateModelAsync(
        string name,
        string? description,
        JsonDocument? parameters,
        Guid createdBy,
        string? createdByName,
        CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(CreateModelAsync));

        ArgumentException.ThrowIfNullOrWhiteSpace(name);

        // createdBy may be Guid.Empty from HTTP call sites — the audit-stamping
        // interceptor will fill it from ICurrentUser. Seeder paths pass explicit
        // fake Guids so the interceptor's "only overwrite defaults" rule leaves
        // them alone.
        var model = new Model
        {
            Id = Guid.NewGuid(),
            Name = name.Trim(),
            Description = description?.Trim(),
            Status = ModelStatus.Draft,
            Version = 1,
            Parameters = parameters,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
            CreatedBy = createdBy,
            CreatedByName = createdByName
        };

        await repository.AddModelAsync(model, cancellationToken);
        await repository.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Created model {ModelId} with name {ModelName}", model.Id, model.Name);

        return model;
    }

    /// <inheritdoc />
    public async Task<Model?> UpdateModelAsync(
        Guid id,
        string name,
        string? description,
        ModelStatus status,
        JsonDocument? parameters,
        CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(UpdateModelAsync));

        ArgumentOutOfRangeException.ThrowIfEqual(id, Guid.Empty);
        ArgumentException.ThrowIfNullOrWhiteSpace(name);

        var model = await repository.GetModelByIdAsync(id, cancellationToken);
        if (model is null)
        {
            logger.LogWarning("Model {ModelId} not found for update", id);
            return null;
        }

        if (model.Status == ModelStatus.Archived)
        {
            logger.LogWarning("Cannot update archived model {ModelId}", id);
            return null;
        }

        model.Name = name.Trim();
        model.Description = description?.Trim();
        model.Status = status;
        model.Parameters = parameters;
        model.Version++;
        model.UpdatedAtUtc = DateTime.UtcNow;

        // UpdatedBy / UpdatedByName are stamped by AuditStampingInterceptor
        // based on ICurrentUser; no explicit assignment needed here.

        await repository.UpdateModelAsync(model, cancellationToken);
        await repository.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Updated model {ModelId} to version {Version}", model.Id, model.Version);

        return model;
    }

    /// <inheritdoc />
    public async Task<bool> ArchiveModelAsync(Guid id, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(ArchiveModelAsync));

        ArgumentOutOfRangeException.ThrowIfEqual(id, Guid.Empty);

        var model = await repository.GetModelByIdAsync(id, cancellationToken);
        if (model is null)
        {
            logger.LogWarning("Model {ModelId} not found for archival", id);
            return false;
        }

        if (model.Status == ModelStatus.Archived)
        {
            logger.LogInformation("Model {ModelId} is already archived", id);
            return true;
        }

        model.Status = ModelStatus.Archived;
        model.UpdatedAtUtc = DateTime.UtcNow;

        await repository.UpdateModelAsync(model, cancellationToken);
        await repository.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Archived model {ModelId}", id);

        return true;
    }

    /// <inheritdoc />
    public async Task<ModelRun?> RequestModelRunAsync(Guid modelId, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(RequestModelRunAsync));

        ArgumentOutOfRangeException.ThrowIfEqual(modelId, Guid.Empty);

        var model = await repository.GetModelByIdAsync(modelId, cancellationToken);
        if (model is null)
        {
            logger.LogWarning("Model {ModelId} not found for run request", modelId);
            return null;
        }

        return await CreateAndPublishRunAsync(model, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<ModelRun>> GetModelRunsAsync(Guid modelId, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(GetModelRunsAsync));

        ArgumentOutOfRangeException.ThrowIfEqual(modelId, Guid.Empty);

        logger.LogInformation("Retrieving runs for model {ModelId}", modelId);

        return await repository.GetModelRunsAsync(modelId, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<ModelRun?> GetModelRunByIdAsync(Guid modelId, Guid runId, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(GetModelRunByIdAsync));

        ArgumentOutOfRangeException.ThrowIfEqual(modelId, Guid.Empty);
        ArgumentOutOfRangeException.ThrowIfEqual(runId, Guid.Empty);

        logger.LogInformation("Retrieving run {ModelRunId} for model {ModelId}", runId, modelId);

        var run = await repository.GetModelRunByIdAsync(runId, cancellationToken);

        if (run is null || run.ModelId != modelId)
        {
            logger.LogWarning("Run {ModelRunId} not found or does not belong to model {ModelId}", runId, modelId);
            return null;
        }

        return run;
    }

    /// <inheritdoc />
    public async Task<(IReadOnlyList<ModelRun> Items, int TotalCount)> GetAllRunsAsync(
        int page, int pageSize, ModelRunStatus? status, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(GetAllRunsAsync));

        ArgumentOutOfRangeException.ThrowIfLessThan(page, 1);
        ArgumentOutOfRangeException.ThrowIfLessThan(pageSize, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(pageSize, 100);

        logger.LogInformation("Retrieving all runs page {Page} with page size {PageSize}, status filter: {Status}",
            page, pageSize, status);

        return await repository.GetAllRunsAsync(page, pageSize, status, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<ModelRun>> RequestBatchRunAsync(
        IReadOnlyList<Guid> modelIds, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity(nameof(RequestBatchRunAsync));

        ArgumentNullException.ThrowIfNull(modelIds);

        logger.LogInformation("Requesting batch run for {Count} models", modelIds.Count);

        using var semaphore = new SemaphoreSlim(BatchMaxConcurrency);
        var tasks = modelIds.Select(async modelId =>
        {
            await semaphore.WaitAsync(cancellationToken);
            try
            {
                return await RequestModelRunAsync(modelId, cancellationToken);
            }
            finally
            {
                semaphore.Release();
            }
        });

        var results = await Task.WhenAll(tasks);
        var runs = results.Where(r => r is not null).Cast<ModelRun>().ToList();

        logger.LogInformation("Batch run completed: {SuccessCount}/{TotalCount} runs created",
            runs.Count, modelIds.Count);

        return runs;
    }

    /// <summary>
    /// Creates a model run, validates the distribution parameter, publishes the message,
    /// and returns the created run. Shared by single and batch run paths.
    /// </summary>
    private async Task<ModelRun?> CreateAndPublishRunAsync(Model model, CancellationToken cancellationToken)
    {
        if (model.Status == ModelStatus.Archived)
        {
            logger.LogWarning("Cannot request run for archived model {ModelId}", model.Id);
            return null;
        }

        // Validate distribution parameter before creating the run
        var distribution = ExtractDistribution(model.Parameters);
        var isUnsupportedDistribution = distribution is null || !SupportedDistributions.Contains(distribution);

        var run = new ModelRun
        {
            Id = Guid.NewGuid(),
            ModelId = model.Id,
            Status = isUnsupportedDistribution ? ModelRunStatus.Failed : ModelRunStatus.Pending,
            RequestedAtUtc = DateTime.UtcNow,
            ErrorMessage = isUnsupportedDistribution
                ? $"Unsupported or missing distribution '{distribution ?? "(none)"}'. Supported distributions: {string.Join(", ", SupportedDistributions.Order())}."
                : null
            // RequestedBy / RequestedByName are filled by AuditStampingInterceptor
            // from ICurrentUser. Data-engine-originated runs (future) will set
            // these explicitly and the interceptor leaves them alone.
        };

        if (isUnsupportedDistribution)
        {
            logger.LogWarning(
                "Model {ModelId} has unsupported distribution '{Distribution}'; run {ModelRunId} marked as Failed immediately",
                model.Id, distribution ?? "(none)", run.Id);

            run.CompletedAtUtc = DateTime.UtcNow;
            await repository.AddModelRunAsync(run, cancellationToken);
            await repository.SaveChangesAsync(cancellationToken);
            return run;
        }

        await repository.AddModelRunAsync(run, cancellationToken);
        await repository.SaveChangesAsync(cancellationToken);

        var correlationId = Guid.NewGuid();
        var message = new ModelRunRequested(
            MessageId: Guid.NewGuid(),
            CorrelationId: correlationId,
            OccurredAtUtc: DateTime.UtcNow,
            ModelId: model.Id,
            ModelRunId: run.Id,
            ModelName: model.Name,
            Parameters: model.Parameters);

        await publishEndpoint.Publish(message, cancellationToken);

        logger.LogInformation(
            "Requested model run {ModelRunId} for model {ModelId}, published message with correlation {CorrelationId}",
            run.Id, model.Id, correlationId);

        return run;
    }

    /// <summary>
    /// Extracts the distribution field from a model's JSON parameters document.
    /// Returns null if parameters are missing or the distribution property is absent.
    /// </summary>
    private static string? ExtractDistribution(JsonDocument? parameters)
    {
        if (parameters is null)
            return null;

        if (parameters.RootElement.TryGetProperty("distribution", out var distributionElement) &&
            distributionElement.ValueKind == JsonValueKind.String)
        {
            return distributionElement.GetString();
        }

        return null;
    }
}
