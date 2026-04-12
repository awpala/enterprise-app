using System.Text.Json;
using EA.Domain.Enums;

namespace EA.Domain.Entities;

/// <summary>
/// Represents a model entity — the primary domain object for data model definitions.
/// </summary>
public class Model
{
    /// <summary>Gets or sets the unique identifier.</summary>
    public Guid Id { get; set; }

    /// <summary>Gets or sets the model name.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Gets or sets the optional description.</summary>
    public string? Description { get; set; }

    /// <summary>Gets or sets the current lifecycle status.</summary>
    public ModelStatus Status { get; set; } = ModelStatus.Draft;

    /// <summary>Gets or sets the version number, incremented on each update.</summary>
    public int Version { get; set; } = 1;

    /// <summary>Gets or sets arbitrary key-value configuration parameters.</summary>
    public JsonDocument? Parameters { get; set; }

    /// <summary>Gets or sets the UTC timestamp when the model was created.</summary>
    public DateTime CreatedAtUtc { get; set; }

    /// <summary>Gets or sets the UTC timestamp when the model was last updated.</summary>
    public DateTime UpdatedAtUtc { get; set; }

    /// <summary>Gets or sets the identifier of the user who created the model.</summary>
    public string CreatedBy { get; set; } = string.Empty;

    /// <summary>Gets or sets the collection of runs executed against this model.</summary>
    public ICollection<ModelRun> Runs { get; set; } = new List<ModelRun>();
}
