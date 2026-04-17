using System.Diagnostics;
using System.Text.Json;
using EA.Domain.Entities;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace EA.Infrastructure.Data.Interceptors;

/// <summary>
/// EF Core interceptor that stamps create/update audit columns on tracked
/// entities from <see cref="ICurrentUser"/> immediately before
/// <c>SaveChanges</c> executes, and emits append-only <see cref="AuditEvent"/>
/// rows for auditable domain entities.
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
///   <item>
///     After stamping, emits <see cref="AuditEvent"/> rows for <see cref="Model"/>
///     and <see cref="ModelRun"/> entities. <see cref="AuditEvent"/> entries are
///     skipped (recursion guard).
///   </item>
/// </list>
/// </remarks>
public sealed class AuditStampingInterceptor(ICurrentUser currentUser) : SaveChangesInterceptor
{
    /// <summary>
    /// Audit-stamp column names excluded from changed-fields detection on updates.
    /// These are columns set by the interceptor itself or by EF value generation,
    /// not by user intent.
    /// </summary>
    private static readonly HashSet<string> AuditStampColumns = new(StringComparer.Ordinal)
    {
        "UpdatedAtUtc",
        nameof(IUpdatedAuditable.UpdatedBy),
        nameof(IUpdatedAuditable.UpdatedByName),
    };

    /// <inheritdoc />
    public override InterceptionResult<int> SavingChanges(
        DbContextEventData eventData,
        InterceptionResult<int> result)
    {
        StampAuditColumns(eventData.Context);
        EmitAuditEvents(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    /// <inheritdoc />
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        StampAuditColumns(eventData.Context);
        EmitAuditEvents(eventData.Context);
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

    /// <summary>
    /// Second pass over the change tracker: creates <see cref="AuditEvent"/> rows
    /// for <see cref="Model"/> and <see cref="ModelRun"/> entities that are being
    /// added or modified.
    /// </summary>
    private void EmitAuditEvents(DbContext? context)
    {
        if (context is null || !currentUser.IsAuthenticated)
            return;

        var now = DateTime.UtcNow;

        // Derive correlation ID from the current OpenTelemetry distributed trace,
        // tying each audit row to the trace visible in Application Insights.
        Guid? correlationId = Activity.Current is { } activity
            ? new Guid(activity.TraceId.ToHexString())
            : null;

        var auditEntries = new List<AuditEvent>();

        foreach (var entry in context.ChangeTracker.Entries())
        {
            // Recursion guard: never audit the audit rows themselves.
            if (entry.Entity is AuditEvent)
                continue;

            if (entry.State is not (EntityState.Added or EntityState.Modified))
                continue;

            var auditEvent = entry.Entity switch
            {
                Model model => BuildModelAuditEvent(entry, model, now, correlationId),
                ModelRun run => BuildModelRunAuditEvent(entry, run, now, correlationId),
                _ => null,
            };

            if (auditEvent is not null)
                auditEntries.Add(auditEvent);
        }

        if (auditEntries.Count > 0)
            context.Set<AuditEvent>().AddRange(auditEntries);
    }

    /// <summary>
    /// Builds an <see cref="AuditEvent"/> for a <see cref="Model"/> entity change.
    /// </summary>
    private AuditEvent BuildModelAuditEvent(EntityEntry entry, Model model, DateTime now, Guid? correlationId)
    {
        string action;
        JsonDocument details;

        if (entry.State == EntityState.Added)
        {
            action = "model.created";
            details = JsonSerializer.SerializeToDocument(new { name = model.Name, status = nameof(ModelStatus.Draft) });
        }
        else if (entry.State == EntityState.Modified
                 && entry.Property(nameof(Model.Status)).IsModified
                 && model.Status == ModelStatus.Archived)
        {
            var previousStatus = entry.Property(nameof(Model.Status)).OriginalValue?.ToString() ?? "unknown";
            action = "model.archived";
            details = JsonSerializer.SerializeToDocument(new { name = model.Name, previousStatus });
        }
        else
        {
            action = "model.updated";
            var changedFields = entry.Properties
                .Where(p => p.IsModified && !AuditStampColumns.Contains(p.Metadata.Name))
                .Select(p => p.Metadata.Name)
                .ToList();
            details = JsonSerializer.SerializeToDocument(new { name = model.Name, version = model.Version, changedFields });
        }

        return AuditEvent.Create(
            occurredAtUtc: now,
            action: action,
            entityType: nameof(Model),
            actorIdp: currentUser.Idp ?? "unknown",
            actorType: "user",
            actorOid: currentUser.Oid,
            actorTid: currentUser.Tid,
            actorName: currentUser.Name,
            actorEmail: currentUser.Email,
            entityId: model.Id,
            details: details,
            correlationId: correlationId);
    }

    /// <summary>
    /// Builds an <see cref="AuditEvent"/> for a <see cref="ModelRun"/> entity addition.
    /// Only <c>Added</c> state is audited; status transitions are driven by consumers.
    /// </summary>
    private AuditEvent? BuildModelRunAuditEvent(EntityEntry entry, ModelRun run, DateTime now, Guid? correlationId)
    {
        if (entry.State != EntityState.Added)
            return null;

        var details = JsonSerializer.SerializeToDocument(new { modelId = run.ModelId, status = nameof(ModelRunStatus.Pending) });

        return AuditEvent.Create(
            occurredAtUtc: now,
            action: "modelrun.requested",
            entityType: nameof(ModelRun),
            actorIdp: currentUser.Idp ?? "unknown",
            actorType: "user",
            actorOid: currentUser.Oid,
            actorTid: currentUser.Tid,
            actorName: currentUser.Name,
            actorEmail: currentUser.Email,
            entityId: run.Id,
            details: details,
            correlationId: correlationId);
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
