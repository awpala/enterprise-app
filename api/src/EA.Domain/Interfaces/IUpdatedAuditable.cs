namespace EA.Domain.Interfaces;

/// <summary>
/// Marker interface identifying entities that carry update-actor audit columns.
/// The audit-stamping <c>SaveChangesInterceptor</c> fills these unconditionally
/// on modify, and on add only when the values are still default.
/// </summary>
public interface IUpdatedAuditable
{
    /// <summary>The Entra object identifier of the actor that last updated the row.</summary>
    Guid? UpdatedBy { get; set; }

    /// <summary>The display name captured at last update.</summary>
    string? UpdatedByName { get; set; }
}
