using System.Text.Json;

namespace EA.Contracts.Models;

/// <summary>
/// Summary DTO for a model, used in list responses.
/// </summary>
public record ModelDto(
    Guid Id,
    string Name,
    string? Description,
    string Status,
    int Version,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    string CreatedBy);
