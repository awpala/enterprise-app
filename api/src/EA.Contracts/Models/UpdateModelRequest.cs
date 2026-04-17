using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace EA.Contracts.Models;

/// <summary>
/// Request payload for updating an existing model.
/// </summary>
public record UpdateModelRequest(
    [Required, MaxLength(200)] string Name,
    [MaxLength(2000)] string? Description,
    [Required] string Status,
    JsonDocument? Parameters);
