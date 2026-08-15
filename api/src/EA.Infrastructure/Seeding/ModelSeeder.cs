using System.Text.Json;
using EA.Domain.Entities;
using EA.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace EA.Infrastructure.Seeding;

/// <summary>
/// Runtime seed applier that inserts missing <see cref="Model"/> rows from JSON
/// files under the configured seed directory. Existing rows matched by identifier
/// are left untouched.
/// </summary>
public sealed class ModelSeeder(ILogger<ModelSeeder> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    /// <summary>
    /// Ensures the database schema is migrated and then seeds models from
    /// <paramref name="seedRootPath"/>/models/*.json.
    /// </summary>
    /// <param name="db">The application DbContext.</param>
    /// <param name="seedRootPath">Root seed directory.</param>
    /// <param name="ct">Cancellation token.</param>
    public async Task SeedAsync(AppDbContext db, string seedRootPath, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentException.ThrowIfNullOrWhiteSpace(seedRootPath);

        await db.Database.MigrateAsync(ct).ConfigureAwait(false);

        var modelsDir = Path.Combine(seedRootPath, "models");
        if (!Directory.Exists(modelsDir))
        {
            logger.LogWarning("Seed directory {ModelsDir} does not exist; skipping model seeding.", modelsDir);
            return;
        }

        var files = Directory.GetFiles(modelsDir, "*.json");
        if (files.Length == 0)
        {
            logger.LogInformation("Seed directory {ModelsDir} is empty; nothing to seed.", modelsDir);
            return;
        }

        var dtos = new List<SeedModelDto>(files.Length);
        foreach (var file in files)
        {
            try
            {
                await using var stream = File.OpenRead(file);
                var dto = await JsonSerializer.DeserializeAsync<SeedModelDto>(stream, JsonOptions, ct)
                    .ConfigureAwait(false);

                if (dto is null)
                {
                    logger.LogWarning("Seed file {File} deserialized to null; skipping.", file);
                    continue;
                }

                dtos.Add(dto);
            }
            catch (JsonException ex)
            {
                logger.LogError(ex, "Failed to parse seed file {File}; skipping.", file);
            }
        }

        if (dtos.Count == 0)
        {
            logger.LogInformation("No valid seed entries parsed; nothing to seed.");
            return;
        }

        var ids = dtos.Select(d => d.Id).ToArray();
        var existingIds = await db.Models
            .AsNoTracking()
            .Where(m => ids.Contains(m.Id))
            .Select(m => m.Id)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        var existingSet = existingIds.ToHashSet();

        var inserted = 0;
        var skipped = 0;

        foreach (var dto in dtos)
        {
            if (existingSet.Contains(dto.Id))
            {
                skipped++;
                continue;
            }

            db.Models.Add(ToEntity(dto));
            inserted++;
        }

        if (inserted > 0)
        {
            await db.SaveChangesAsync(ct).ConfigureAwait(false);
        }

        logger.LogInformation(
            "Seeding: inserted {Inserted}, skipped {Skipped} existing (out of {Total}).",
            inserted, skipped, dtos.Count);
    }

    private static Model ToEntity(SeedModelDto dto)
    {
        JsonDocument? parameters = null;
        if (dto.Parameters is not null)
        {
            parameters = JsonDocument.Parse(dto.Parameters.ToJsonString());
        }

        return new Model
        {
            Id = dto.Id,
            Name = dto.Name,
            Description = dto.Description,
            Status = dto.Status,
            Version = dto.Version,
            Parameters = parameters,
            CreatedAtUtc = DateTime.SpecifyKind(dto.CreatedAtUtc, DateTimeKind.Utc),
            UpdatedAtUtc = DateTime.SpecifyKind(dto.UpdatedAtUtc, DateTimeKind.Utc),
            CreatedBy = dto.CreatedBy,
            CreatedByName = dto.CreatedByName
        };
    }
}
