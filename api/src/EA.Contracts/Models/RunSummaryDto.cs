namespace EA.Contracts.Models;

/// <summary>
/// Summary DTO for a model run in cross-model listing, includes model name.
/// </summary>
public record RunSummaryDto(
    Guid Id,
    Guid ModelId,
    string ModelName,
    string Status,
    DateTime RequestedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? CompletedAtUtc,
    string? ErrorMessage);
