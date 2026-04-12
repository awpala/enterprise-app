using EA.Contracts.Messages;
using EA.Domain.Entities;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using MassTransit;
using Microsoft.Extensions.Logging;

namespace EA.Infrastructure.Consumers;

/// <summary>
/// MassTransit consumer that handles <see cref="ModelRunCompleted"/> messages.
/// Updates the model run status, persists computed metrics, and stores the result summary.
/// </summary>
public class ModelRunCompletedConsumer(
    IModelRepository repository,
    ILogger<ModelRunCompletedConsumer> logger) : IConsumer<ModelRunCompleted>
{
    /// <inheritdoc />
    public async Task Consume(ConsumeContext<ModelRunCompleted> context)
    {
        var message = context.Message;
        logger.LogInformation("Received ModelRunCompleted for run {ModelRunId}, model {ModelId}",
            message.ModelRunId, message.ModelId);

        var run = await repository.GetModelRunByIdAsync(message.ModelRunId, context.CancellationToken);
        if (run is null)
        {
            logger.LogWarning("Model run {ModelRunId} not found, skipping", message.ModelRunId);
            return;
        }

        run.Status = ModelRunStatus.Completed;
        run.CompletedAtUtc = message.OccurredAtUtc;
        run.ResultSummary = message.ResultSummary;

        await repository.UpdateModelRunAsync(run, context.CancellationToken);

        var metrics = message.Metrics.Select(m => new ModelMetric
        {
            Id = Guid.NewGuid(),
            ModelRunId = run.Id,
            MetricName = m.Name,
            MetricValue = m.Value,
            CalculatedAtUtc = message.OccurredAtUtc
        });

        await repository.AddModelMetricsAsync(metrics, context.CancellationToken);
        await repository.SaveChangesAsync(context.CancellationToken);

        logger.LogInformation("Model run {ModelRunId} completed with {MetricCount} metrics",
            message.ModelRunId, message.Metrics.Count);
    }
}
