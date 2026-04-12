using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace EA.Contracts.Models;

/// <summary>
/// Request payload for updating an existing model.
/// </summary>
public record UpdateModelRequest(
    [property: Required, MaxLength(200)] string Name,
    [property: MaxLength(2000)] string? Description,
    [property: Required] string Status,
    JsonDocument? Parameters);
