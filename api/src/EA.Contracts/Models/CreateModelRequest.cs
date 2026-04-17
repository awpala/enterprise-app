using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace EA.Contracts.Models;

/// <summary>
/// Request payload for creating a new model.
/// </summary>
public record CreateModelRequest(
    [Required, MaxLength(200)] string Name,
    [MaxLength(2000)] string? Description,
    JsonDocument? Parameters);
