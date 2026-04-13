namespace EA.Domain.Interfaces;

/// <summary>
/// Marker interface identifying entities that carry creation-actor audit columns.
/// Populated by the audit-stamping <c>SaveChangesInterceptor</c> during Phase 2B;
/// seeders and system paths can set explicit values and the interceptor will
/// respect them when <see cref="ICurrentUser.IsAuthenticated"/> is false.
/// </summary>
public interface ICreatedAuditable
{
    /// <summary>The Entra object identifier of the actor that created the row.</summary>
    Guid CreatedBy { get; set; }

    /// <summary>The display name captured at creation time. Optional — some IDPs do not emit a name claim.</summary>
    string? CreatedByName { get; set; }
}
