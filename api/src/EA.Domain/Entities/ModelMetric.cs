namespace EA.Domain.Entities;

/// <summary>
/// Represents a computed metric produced by a model run.
/// </summary>
public class ModelMetric
{
    /// <summary>Gets or sets the unique identifier.</summary>
    public Guid Id { get; set; }

    /// <summary>Gets or sets the foreign key to the parent model run.</summary>
    public Guid ModelRunId { get; set; }

    /// <summary>Gets or sets the name of the metric.</summary>
    public string MetricName { get; set; } = string.Empty;

    /// <summary>Gets or sets the computed value of the metric.</summary>
    public decimal MetricValue { get; set; }

    /// <summary>Gets or sets the UTC timestamp when the metric was calculated.</summary>
    public DateTime CalculatedAtUtc { get; set; }

    /// <summary>Gets or sets the parent model run navigation property.</summary>
    public ModelRun ModelRun { get; set; } = null!;
}
