namespace EA.Contracts.Models;

/// <summary>
/// Summary DTO for a model run, used in list responses.
/// </summary>
public record ModelRunDto(
    Guid Id,
    Guid ModelId,
    string Status,
    DateTime RequestedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? CompletedAtUtc,
    string? ErrorMessage);
