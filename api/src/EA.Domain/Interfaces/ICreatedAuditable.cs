namespace EA.Domain.Interfaces;

/// <summary>
/// Marker interface identifying entities that carry creation-actor audit columns.
/// The audit-stamping interceptor fills default values for authenticated writes;
/// seeders and other non-HTTP paths can supply explicit values.
/// </summary>
public interface ICreatedAuditable
{
    /// <summary>The normalized subject identifier of the actor that created the row.</summary>
    Guid CreatedBy { get; set; }

    /// <summary>The display name captured at creation time. Optional — some IDPs do not emit a name claim.</summary>
    string? CreatedByName { get; set; }
}
