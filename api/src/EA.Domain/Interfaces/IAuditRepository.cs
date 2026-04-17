using EA.Domain.Entities;

namespace EA.Domain.Interfaces;

/// <summary>
/// Read-only repository for querying audit events.
/// </summary>
public interface IAuditRepository
{
    /// <summary>
    /// Retrieves a paged list of audit events with optional filters.
    /// </summary>
    /// <param name="page">Page number (1-based).</param>
    /// <param name="pageSize">Number of items per page.</param>
    /// <param name="entityType">Optional filter by entity type (e.g. "Model", "ModelRun").</param>
    /// <param name="entityId">Optional filter by entity identifier.</param>
    /// <param name="actorOid">Optional filter by actor Entra object identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A tuple of the paged items and the total count matching the filters.</returns>
    Task<(IReadOnlyList<AuditEvent> Items, int TotalCount)> GetAuditEventsAsync(
        int page,
        int pageSize,
        string? entityType = null,
        Guid? entityId = null,
        Guid? actorOid = null,
        CancellationToken cancellationToken = default);
}
