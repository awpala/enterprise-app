namespace EA.Domain.Entities;

/// <summary>
/// Append-only audit record capturing a single domain action. Rows are emitted
/// by <c>AuditStampingInterceptor</c> during <c>SaveChanges</c> for auditable
/// entities (<c>Model</c>, <c>ModelRun</c>).
/// </summary>
/// <remarks>
/// Property setters are <c>private</c> so rows are only built via
/// <see cref="Create"/>. The empty constructor exists for EF Core materialization.
/// </remarks>
public class AuditEvent
{
    /// <summary>Required by EF Core for materialization.</summary>
    private AuditEvent()
    {
    }

    /// <summary>Gets the unique identifier of the audit row.</summary>
    public Guid Id { get; private set; }

    /// <summary>Gets the UTC timestamp at which the action occurred.</summary>
    public DateTime OccurredAtUtc { get; private set; }

    /// <summary>Gets the Entra object identifier of the actor, if known.</summary>
    public Guid? ActorOid { get; private set; }

    /// <summary>Gets the Entra tenant identifier of the actor, if known.</summary>
    public Guid? ActorTid { get; private set; }

    /// <summary>Gets the display name of the actor. PII — handle per retention policy.</summary>
    public string? ActorName { get; private set; }

    /// <summary>Gets the email address of the actor. PII — handle per retention policy.</summary>
    public string? ActorEmail { get; private set; }

    /// <summary>
    /// Gets the upstream identity provider the actor authenticated with.
    /// Examples: <c>"google.com"</c>, <c>"live.com"</c>, <c>"entra"</c>,
    /// <c>"email"</c>, <c>"dev"</c>, <c>"system"</c>.
    /// </summary>
    public string ActorIdp { get; private set; } = string.Empty;

    /// <summary>
    /// Gets the class of actor. One of <c>"user"</c>, <c>"service_principal"</c>,
    /// or <c>"system"</c>.
    /// </summary>
    public string ActorType { get; private set; } = string.Empty;

    /// <summary>
    /// Gets the action identifier, e.g. <c>"model.created"</c>,
    /// <c>"modelrun.requested"</c>. Format is <c>{entity}.{verb}</c>.
    /// </summary>
    public string Action { get; private set; } = string.Empty;

    /// <summary>Gets the affected entity type, e.g. <c>"Model"</c> or <c>"ModelRun"</c>.</summary>
    public string EntityType { get; private set; } = string.Empty;

    /// <summary>Gets the affected entity identifier, if any.</summary>
    public Guid? EntityId { get; private set; }

    /// <summary>
    /// Gets the JSON payload capturing action-specific context. Stored as
    /// <c>jsonb</c> in Postgres. Defaults to <c>"{}"</c> for rows with no detail.
    /// </summary>
    public string Details { get; private set; } = "{}";

    /// <summary>Gets the correlation identifier linking this event to a request or message.</summary>
    public Guid? CorrelationId { get; private set; }

    /// <summary>
    /// Factory method for building an audit row. Kept as the only construction
    /// path so consumers cannot forget to set required fields.
    /// </summary>
    /// <param name="occurredAtUtc">When the action happened.</param>
    /// <param name="action">Action identifier (e.g. <c>"model.created"</c>).</param>
    /// <param name="entityType">Affected entity type name.</param>
    /// <param name="actorIdp">Upstream identity provider identifier.</param>
    /// <param name="actorType">Actor class (<c>"user"</c>, <c>"service_principal"</c>, <c>"system"</c>).</param>
    /// <param name="actorOid">Actor object identifier, if known.</param>
    /// <param name="actorTid">Actor tenant identifier, if known.</param>
    /// <param name="actorName">Actor display name.</param>
    /// <param name="actorEmail">Actor email.</param>
    /// <param name="entityId">Affected entity identifier.</param>
    /// <param name="details">Action-specific JSON payload.</param>
    /// <param name="correlationId">Request / message correlation identifier.</param>
    public static AuditEvent Create(
        DateTime occurredAtUtc,
        string action,
        string entityType,
        string actorIdp,
        string actorType,
        Guid? actorOid = null,
        Guid? actorTid = null,
        string? actorName = null,
        string? actorEmail = null,
        Guid? entityId = null,
        string? details = null,
        Guid? correlationId = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(action);
        ArgumentException.ThrowIfNullOrWhiteSpace(entityType);
        ArgumentException.ThrowIfNullOrWhiteSpace(actorIdp);
        ArgumentException.ThrowIfNullOrWhiteSpace(actorType);

        return new AuditEvent
        {
            Id = Guid.NewGuid(),
            OccurredAtUtc = occurredAtUtc,
            Action = action,
            EntityType = entityType,
            ActorIdp = actorIdp,
            ActorType = actorType,
            ActorOid = actorOid,
            ActorTid = actorTid,
            ActorName = actorName,
            ActorEmail = actorEmail,
            EntityId = entityId,
            Details = string.IsNullOrWhiteSpace(details) ? "{}" : details,
            CorrelationId = correlationId,
        };
    }
}
