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
        logger.LogInformation("Received ModelRunFailed for run {ModelRunId}", message.ModelRunId);

        var run = await repository.GetModelRunByIdAsync(message.ModelRunId, context.CancellationToken);
        if (run is null)
        {
            logger.LogWarning("Model run {ModelRunId} not found, skipping", message.ModelRunId);
            return;
        }

        run.Status = ModelRunStatus.Failed;
        run.CompletedAtUtc = message.OccurredAtUtc;
        run.ErrorMessage = message.ErrorMessage;

        await repository.UpdateModelRunAsync(run, context.CancellationToken);
        await repository.SaveChangesAsync(context.CancellationToken);

        logger.LogWarning("Model run {ModelRunId} failed: {ErrorMessage}",
            message.ModelRunId, message.ErrorMessage);
    }
}
