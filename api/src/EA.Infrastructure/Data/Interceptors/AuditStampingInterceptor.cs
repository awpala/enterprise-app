using EA.Domain.Entities;
using EA.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace EA.Infrastructure.Data.Interceptors;

/// <summary>
/// EF Core interceptor that stamps create/update audit columns on tracked
/// entities from <see cref="ICurrentUser"/> immediately before
/// <c>SaveChanges</c> executes.
/// </summary>
/// <remarks>
/// <para>
/// Rules:
/// </para>
/// <list type="bullet">
///   <item>
///     Skips entirely when <see cref="ICurrentUser.IsAuthenticated"/> is false.
///     That covers the startup seeder (no <c>HttpContext</c>) and any future
///     out-of-band maintenance paths; those call sites must populate audit
///     columns explicitly.
///   </item>
///   <item>
///     For <see cref="ICreatedAuditable"/>: on <c>Added</c>, fills
///     <c>CreatedBy</c> / <c>CreatedByName</c> only when the current values
///     are still defaults. This lets explicit seeder values win.
///   </item>
///   <item>
///     For <see cref="IUpdatedAuditable"/>: on <c>Modified</c>, overwrites
///     unconditionally. On <c>Added</c>, fills only when default.
///   </item>
///   <item>
///     For <see cref="ModelRun"/>: on <c>Added</c>, fills <c>RequestedBy</c> /
///     <c>RequestedByName</c> when <c>RequestedBy</c> is null. Not routed
///     through the marker-interface path because the column names are
///     domain-specific.
///   </item>
/// </list>
/// </remarks>
public sealed class AuditStampingInterceptor(ICurrentUser currentUser) : SaveChangesInterceptor
{
    /// <inheritdoc />
    public override InterceptionResult<int> SavingChanges(
        DbContextEventData eventData,
        InterceptionResult<int> result)
    {
        StampAuditColumns(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    /// <inheritdoc />
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        StampAuditColumns(eventData.Context);
        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    private void StampAuditColumns(DbContext? context)
    {
        if (context is null || !currentUser.IsAuthenticated)
            return;

        var actorOid = currentUser.Oid ?? Guid.Empty;
        var actorName = currentUser.Name;

        foreach (var entry in context.ChangeTracker.Entries())
        {
            if (entry.State is not (EntityState.Added or EntityState.Modified))
                continue;

            StampCreated(entry, actorOid, actorName);
            StampUpdated(entry, actorOid, actorName);
            StampModelRunRequested(entry, actorOid, actorName);
        }
    }

    private static void StampCreated(EntityEntry entry, Guid actorOid, string? actorName)
    {
        if (entry.State != EntityState.Added || entry.Entity is not ICreatedAuditable created)
            return;

        if (created.CreatedBy == Guid.Empty)
            created.CreatedBy = actorOid;

        if (string.IsNullOrWhiteSpace(created.CreatedByName))
            created.CreatedByName = actorName;
    }

    private static void StampUpdated(EntityEntry entry, Guid actorOid, string? actorName)
    {
        if (entry.Entity is not IUpdatedAuditable updated)
            return;

        if (entry.State == EntityState.Modified)
        {
            updated.UpdatedBy = actorOid;
            updated.UpdatedByName = actorName;
            return;
        }

        // Added: only fill if the caller didn't set anything explicitly.
        if (!updated.UpdatedBy.HasValue)
            updated.UpdatedBy = actorOid;

        if (string.IsNullOrWhiteSpace(updated.UpdatedByName))
            updated.UpdatedByName = actorName;
    }

    private static void StampModelRunRequested(EntityEntry entry, Guid actorOid, string? actorName)
    {
        if (entry.State != EntityState.Added || entry.Entity is not ModelRun run)
            return;

        if (!run.RequestedBy.HasValue)
            run.RequestedBy = actorOid;

        if (string.IsNullOrWhiteSpace(run.RequestedByName))
            run.RequestedByName = actorName;
    }
}
