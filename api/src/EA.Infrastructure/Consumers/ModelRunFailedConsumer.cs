using EA.Contracts.Messages;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using MassTransit;
using Microsoft.Extensions.Logging;

namespace EA.Infrastructure.Consumers;

/// <summary>
/// MassTransit consumer that handles <see cref="ModelRunFailed"/> messages.
/// Updates the model run status to Failed and records the error message.
/// </summary>
public class ModelRunFailedConsumer(
    IModelRepository repository,
    ILogger<ModelRunFailedConsumer> logger) : IConsumer<ModelRunFailed>
{
    /// <inheritdoc />
    public async Task Consume(ConsumeContext<ModelRunFailed> context)
    {
        var message = context.Message;
        logger.LogInformation(
            "Received ModelRunFailed for run {ModelRunId}, model {ModelId} (MessageId: {MessageId}, CorrelationId: {CorrelationId})",
            message.ModelRunId, message.ModelId, message.MessageId, message.CorrelationId);

        var updated = await repository.MarkModelRunFailedAsync(
            message.ModelRunId,
            message.OccurredAtUtc,
            message.ErrorMessage,
            context.CancellationToken);
        if (!updated)
        {
            logger.LogWarning("Model run {ModelRunId} not found, skipping", message.ModelRunId);
            return;
        }

        logger.LogWarning("Model run {ModelRunId} failed: {ErrorMessage}",
            message.ModelRunId, message.ErrorMessage);
    }
}
