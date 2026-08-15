using EA.Domain.Entities;
using EA.Domain.Interfaces;
using EA.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace EA.Infrastructure.Repositories;

/// <summary>
/// EF Core implementation of <see cref="IAuditRepository"/>.
/// All queries are read-only (<see cref="EntityFrameworkQueryableExtensions.AsNoTracking{TEntity}"/>).
/// </summary>
public class AuditRepository(AppDbContext dbContext) : IAuditRepository
{
    /// <inheritdoc />
    public async Task<(IReadOnlyList<AuditEvent> Items, int TotalCount)> GetAuditEventsAsync(
        int page,
        int pageSize,
        string? entityType = null,
        Guid? entityId = null,
        Guid? actorSubjectId = null,
        CancellationToken cancellationToken = default)
    {
        var query = dbContext.AuditEvents.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(entityType))
            query = query.Where(e => e.EntityType == entityType);

        if (entityId.HasValue)
            query = query.Where(e => e.EntityId == entityId.Value);

        if (actorSubjectId.HasValue)
            query = query.Where(e => e.ActorSubjectId == actorSubjectId.Value);

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(e => e.OccurredAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }
}
