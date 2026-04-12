using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace EA.Contracts.Models;

/// <summary>
/// Request payload for creating a new model.
/// </summary>
public record CreateModelRequest(
    [property: Required, MaxLength(200)] string Name,
    [property: MaxLength(2000)] string? Description,
    JsonDocument? Parameters);
