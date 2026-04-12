using System.Text.Json;

namespace EA.Contracts.Models;

/// <summary>
/// Detailed DTO for a model, including parameters and latest run summary.
/// </summary>
public record ModelDetailDto(
    Guid Id,
    string Name,
    string? Description,
    string Status,
    int Version,
    JsonDocument? Parameters,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    string CreatedBy,
    ModelRunDto? LatestRun);
