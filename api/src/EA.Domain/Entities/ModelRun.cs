using System.Text.Json;
using EA.Domain.Enums;

namespace EA.Domain.Entities;

/// <summary>
/// Represents a single execution run of a model.
/// </summary>
public class ModelRun
{
    /// <summary>Gets or sets the unique identifier.</summary>
    public Guid Id { get; set; }

    /// <summary>Gets or sets the foreign key to the parent model.</summary>
    public Guid ModelId { get; set; }

    /// <summary>Gets or sets the current execution status.</summary>
    public ModelRunStatus Status { get; set; } = ModelRunStatus.Pending;

    /// <summary>Gets or sets the UTC timestamp when the run was requested.</summary>
    public DateTime RequestedAtUtc { get; set; }

    /// <summary>Gets or sets the UTC timestamp when the run started executing.</summary>
    public DateTime? StartedAtUtc { get; set; }

    /// <summary>Gets or sets the UTC timestamp when the run completed.</summary>
    public DateTime? CompletedAtUtc { get; set; }

    /// <summary>Gets or sets the aggregated result summary as JSON.</summary>
    public JsonDocument? ResultSummary { get; set; }

    /// <summary>Gets or sets the pre-computed histogram data (bin edges, counts) as JSON for visualization.</summary>
    public JsonDocument? SampleData { get; set; }

    /// <summary>Gets or sets the error message if the run failed.</summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// Gets or sets the normalized subject identifier of the user who requested the run.
    /// Nullable because some runs may be triggered by the data engine itself
    /// rather than by an interactive user.
    /// </summary>
    public Guid? RequestedBy { get; set; }

    /// <summary>Gets or sets the display name of the user who requested the run.</summary>
    public string? RequestedByName { get; set; }

    /// <summary>Gets or sets the parent model navigation property.</summary>
    public Model Model { get; set; } = null!;

    /// <summary>Gets or sets the collection of computed metrics for this run.</summary>
    public ICollection<ModelMetric> Metrics { get; set; } = new List<ModelMetric>();
}
