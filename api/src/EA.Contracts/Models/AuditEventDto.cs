namespace EA.Contracts.Models;

/// <summary>
/// DTO for an audit event in API responses.
/// </summary>
public record AuditEventDto(
    Guid Id,
    DateTime OccurredAtUtc,
    Guid? ActorSubjectId,
    string? ActorName,
    string? ActorEmail,
    string ActorIdentityProvider,
    string ActorType,
    string Action,
    string EntityType,
    Guid? EntityId,
    object? Details,
    Guid? CorrelationId);
