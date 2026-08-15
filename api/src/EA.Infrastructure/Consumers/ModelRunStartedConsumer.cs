using EA.Contracts.Messages;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using MassTransit;
using Microsoft.Extensions.Logging;

namespace EA.Infrastructure.Consumers;

/// <summary>
/// MassTransit consumer that handles <see cref="ModelRunStarted"/> messages.
/// Updates the model run status to Running.
/// </summary>
public class ModelRunStartedConsumer(
    IModelRepository repository,
    ILogger<ModelRunStartedConsumer> logger) : IConsumer<ModelRunStarted>
{
    /// <inheritdoc />
    public async Task Consume(ConsumeContext<ModelRunStarted> context)
    {
        var message = context.Message;
        logger.LogInformation(
            "Received ModelRunStarted for run {ModelRunId}, model {ModelId} (MessageId: {MessageId}, CorrelationId: {CorrelationId})",
            message.ModelRunId, message.ModelId, message.MessageId, message.CorrelationId);

        var updated = await repository.MarkModelRunStartedAsync(
            message.ModelRunId,
            message.OccurredAtUtc,
            context.CancellationToken);
        if (!updated)
        {
            logger.LogWarning("Model run {ModelRunId} not found, skipping", message.ModelRunId);
            return;
        }

        logger.LogInformation("Model run {ModelRunId} marked as Running", message.ModelRunId);
    }
}
