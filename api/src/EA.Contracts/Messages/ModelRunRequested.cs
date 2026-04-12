using System.Text.Json;

namespace EA.Contracts.Messages;

/// <summary>
/// Message published when a new model run is requested.
/// </summary>
public record ModelRunRequested(
    Guid MessageId,
    Guid CorrelationId,
    DateTime OccurredAtUtc,
    Guid ModelId,
    Guid ModelRunId,
    string ModelName,
    JsonDocument? Parameters);
