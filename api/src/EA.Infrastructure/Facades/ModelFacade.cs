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
    /// <inheritdoc />
    public async Task<(IReadOnlyList<Model> Items, int TotalCount)> GetModelsAsync(
        int page,
        int pageSize,
        ModelStatus? status,
        CancellationToken cancellationToken = default)
    {
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
        ArgumentOutOfRangeException.ThrowIfEqual(id, Guid.Empty);

        logger.LogInformation("Retrieving model {ModelId}", id);

        return await repository.GetModelByIdAsync(id, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<Model> CreateModelAsync(
        string name,
        string? description,
        JsonDocument? parameters,
        string createdBy,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(createdBy);

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
            CreatedBy = createdBy
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

        await repository.UpdateModelAsync(model, cancellationToken);
        await repository.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Updated model {ModelId} to version {Version}", model.Id, model.Version);

        return model;
    }

    /// <inheritdoc />
    public async Task<bool> ArchiveModelAsync(Guid id, CancellationToken cancellationToken = default)
    {
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
        ArgumentOutOfRangeException.ThrowIfEqual(modelId, Guid.Empty);

        var model = await repository.GetModelByIdAsync(modelId, cancellationToken);
        if (model is null)
        {
            logger.LogWarning("Model {ModelId} not found for run request", modelId);
            return null;
        }

        if (model.Status == ModelStatus.Archived)
        {
            logger.LogWarning("Cannot request run for archived model {ModelId}", modelId);
            return null;
        }

        var run = new ModelRun
        {
            Id = Guid.NewGuid(),
            ModelId = modelId,
            Status = ModelRunStatus.Pending,
            RequestedAtUtc = DateTime.UtcNow
        };

        await repository.AddModelRunAsync(run, cancellationToken);
        await repository.SaveChangesAsync(cancellationToken);

        var correlationId = Guid.NewGuid();
        var message = new ModelRunRequested(
            MessageId: Guid.NewGuid(),
            CorrelationId: correlationId,
            OccurredAtUtc: DateTime.UtcNow,
            ModelId: modelId,
            ModelRunId: run.Id,
            ModelName: model.Name,
            Parameters: model.Parameters);

        await publishEndpoint.Publish(message, cancellationToken);

        logger.LogInformation(
            "Requested model run {ModelRunId} for model {ModelId}, published message with correlation {CorrelationId}",
            run.Id, modelId, correlationId);

        return run;
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<ModelRun>> GetModelRunsAsync(Guid modelId, CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfEqual(modelId, Guid.Empty);

        logger.LogInformation("Retrieving runs for model {ModelId}", modelId);

        return await repository.GetModelRunsAsync(modelId, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<ModelRun?> GetModelRunByIdAsync(Guid modelId, Guid runId, CancellationToken cancellationToken = default)
    {
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
}
