using System.Text.Json;
using System.Text.Json.Nodes;
using EA.Domain.Enums;

namespace EA.Infrastructure.Seeding;

/// <summary>
/// JSON-serializable representation of a seeded <see cref="Domain.Entities.Model"/>.
/// Shared between the design-time generator and the runtime applier so both sides
/// agree on the on-disk contract.
/// </summary>
public sealed record SeedModelDto
{
    /// <summary>Gets the deterministic model identifier.</summary>
    public required Guid Id { get; init; }

    /// <summary>Gets the model name.</summary>
    public required string Name { get; init; }

    /// <summary>Gets the optional description.</summary>
    public string? Description { get; init; }

    /// <summary>Gets the lifecycle status.</summary>
    public required ModelStatus Status { get; init; }

    /// <summary>Gets the version number.</summary>
    public required int Version { get; init; }

    /// <summary>
    /// Gets the model parameters as a loosely-typed JSON node so the DTO can be
    /// round-tripped without rebuilding a <see cref="JsonDocument"/>.
    /// </summary>
    public JsonNode? Parameters { get; init; }

    /// <summary>Gets the UTC creation timestamp.</summary>
    public required DateTime CreatedAtUtc { get; init; }

    /// <summary>Gets the UTC last-updated timestamp.</summary>
    public required DateTime UpdatedAtUtc { get; init; }

    /// <summary>
    /// Gets the deterministic fake Entra object identifier of the seed creator.
    /// Derived from <see cref="CreatedByName"/> so regenerating the seed produces
    /// the same Guid.
    /// </summary>
    public required Guid CreatedBy { get; init; }

    /// <summary>Gets the display name captured at seed-creation time.</summary>
    public required string CreatedByName { get; init; }
}

/// <summary>
/// Manifest entry listing a single seeded model by id and name.
/// </summary>
public sealed record SeedManifestEntry(Guid Id, string Name);

/// <summary>
/// Top-level manifest written alongside individual seed files.
/// </summary>
public sealed record SeedManifest(int Count, IReadOnlyList<SeedManifestEntry> Models);
