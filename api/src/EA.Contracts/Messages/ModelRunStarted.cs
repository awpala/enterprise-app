namespace EA.Contracts.Messages;

/// <summary>
/// Message published when a model run begins execution.
/// </summary>
public record ModelRunStarted(
    Guid MessageId,
    Guid CorrelationId,
    DateTime OccurredAtUtc,
    Guid ModelRunId,
    Guid ModelId);
