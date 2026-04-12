namespace EA.Contracts.Messages;

/// <summary>
/// Message published when a model run fails during execution.
/// </summary>
public record ModelRunFailed(
    Guid MessageId,
    Guid CorrelationId,
    DateTime OccurredAtUtc,
    Guid ModelRunId,
    Guid ModelId,
    string ErrorMessage);
