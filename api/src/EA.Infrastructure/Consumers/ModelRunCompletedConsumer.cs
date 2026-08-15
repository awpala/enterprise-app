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
        logger.LogInformation(
            "Received ModelRunCompleted for run {ModelRunId}, model {ModelId} (MessageId: {MessageId}, CorrelationId: {CorrelationId})",
            message.ModelRunId, message.ModelId, message.MessageId, message.CorrelationId);

        var updated = await repository.MarkModelRunCompletedAsync(
            message.ModelRunId,
            message.OccurredAtUtc,
            message.ResultSummary,
            message.HistogramData,
            context.CancellationToken);
        if (!updated)
        {
            logger.LogWarning("Model run {ModelRunId} not found, skipping", message.ModelRunId);
            return;
        }

        var metrics = message.Metrics.Select(m => new ModelMetric
        {
            Id = Guid.NewGuid(),
            ModelRunId = message.ModelRunId,
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
