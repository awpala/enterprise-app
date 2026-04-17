using System.Text.Json;

namespace EA.Contracts.Messages;

/// <summary>
/// Message published when a model run completes successfully.
/// </summary>
public record ModelRunCompleted(
    Guid MessageId,
    Guid CorrelationId,
    DateTime OccurredAtUtc,
    Guid ModelRunId,
    Guid ModelId,
    IReadOnlyList<MetricResult> Metrics,
    JsonDocument? ResultSummary,
    JsonDocument? HistogramData);

/// <summary>
/// Represents a single computed metric result within a completed run message.
/// </summary>
public record MetricResult(
    string Name,
    decimal Value);
