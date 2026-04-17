using System.Text.Json;

namespace EA.Contracts.Models;

/// <summary>
/// Detailed DTO for a model run, including metrics, result summary, and sample data.
/// </summary>
public record ModelRunDetailDto(
    Guid Id,
    Guid ModelId,
    string Status,
    DateTime RequestedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? CompletedAtUtc,
    JsonDocument? ResultSummary,
    string? ErrorMessage,
    IReadOnlyList<ModelMetricDto> Metrics,
    JsonDocument? SampleData);
