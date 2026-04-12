namespace EA.Contracts.Models;

/// <summary>
/// DTO for a computed metric from a model run.
/// </summary>
public record ModelMetricDto(
    Guid Id,
    string MetricName,
    decimal MetricValue,
    DateTime CalculatedAtUtc);
