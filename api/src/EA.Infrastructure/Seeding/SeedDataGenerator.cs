using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using EA.Domain.Enums;

namespace EA.Infrastructure.Seeding;

/// <summary>
/// Design-time generator that produces deterministic seed JSON files for
/// <see cref="Domain.Entities.Model"/>. Output is committed to source control
/// and consumed by <see cref="ModelSeeder"/> at runtime.
/// </summary>
public static class SeedDataGenerator
{
    private const int ModelCount = 20;
    private const string GuidNamespace = "ea-seed-model";
    private static readonly DateTime BaseDateUtc = new(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    private static readonly string[] NamePool =
    [
        "Revenue Forecast Model",
        "Customer Churn Predictor",
        "Inventory Optimization",
        "Risk Exposure Model",
        "Marketing Attribution",
        "Demand Planning Model",
        "Fraud Detection Scorer",
        "Supply Chain Simulator",
        "Price Elasticity Model",
        "Sentiment Classifier"
    ];

    private static readonly string?[] DescriptionPool =
    [
        "Quarterly projection using Monte Carlo sampling.",
        "Scores customer likelihood of churn over a 90-day window.",
        "Optimizes warehouse stock levels against demand variance.",
        "Estimates portfolio exposure under stressed market scenarios.",
        "Attributes revenue across multi-touch campaign journeys.",
        null,
        "Baseline model pending review.",
        null
    ];

    private static readonly string[] CreatedByPool =
    [
        "alice@example.com",
        "bob@example.com",
        "carol@example.com",
        "seed-user"
    ];

    private static readonly string[] Distributions = ["normal", "uniform", "lognormal", "triangular"];

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    /// <summary>
    /// Generates <see cref="ModelCount"/> seed model JSON files plus a manifest
    /// under <paramref name="outputDirectory"/>. The directory is created if
    /// missing; existing model JSON files are overwritten.
    /// </summary>
    /// <param name="outputDirectory">Root seed directory (e.g. <c>/workspace/api/seed</c>).</param>
    public static void Generate(string outputDirectory)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(outputDirectory);

        var modelsDir = Path.Combine(outputDirectory, "models");
        Directory.CreateDirectory(modelsDir);

        var rng = new Random(42);
        var manifestEntries = new List<SeedManifestEntry>(ModelCount);

        for (var i = 0; i < ModelCount; i++)
        {
            var dto = BuildDto(i, rng);
            manifestEntries.Add(new SeedManifestEntry(dto.Id, dto.Name));

            var filePath = Path.Combine(modelsDir, $"{dto.Id}.json");
            using var stream = File.Create(filePath);
            JsonSerializer.Serialize(stream, dto, JsonOptions);
        }

        var manifest = new SeedManifest(manifestEntries.Count, manifestEntries);
        var manifestPath = Path.Combine(outputDirectory, "models.json");
        using var manifestStream = File.Create(manifestPath);
        JsonSerializer.Serialize(manifestStream, manifest, JsonOptions);
    }

    private static SeedModelDto BuildDto(int index, Random rng)
    {
        var id = DeterministicGuid($"{GuidNamespace}-{index}");
        var baseName = NamePool[index % NamePool.Length];
        var name = $"{baseName} #{index + 1:D2}";

        var description = DescriptionPool[index % DescriptionPool.Length];
        var status = PickStatus(rng);
        var version = rng.Next(1, 6);
        var parameters = BuildParameters(rng);

        var createdAt = BaseDateUtc.AddDays(index);
        var updatedAt = createdAt.AddHours(rng.Next(0, 30 * 24));

        var createdBy = CreatedByPool[index % CreatedByPool.Length];

        return new SeedModelDto
        {
            Id = id,
            Name = name,
            Description = description,
            Status = status,
            Version = version,
            Parameters = parameters,
            CreatedAtUtc = createdAt,
            UpdatedAtUtc = updatedAt,
            CreatedBy = createdBy
        };
    }

    private static ModelStatus PickStatus(Random rng)
    {
        var roll = rng.NextDouble();
        return roll switch
        {
            < 0.60 => ModelStatus.Active,
            < 0.90 => ModelStatus.Draft,
            _ => ModelStatus.Archived
        };
    }

    private static JsonNode BuildParameters(Random rng)
    {
        var distribution = Distributions[rng.Next(Distributions.Length)];
        var mean = Math.Round(rng.NextDouble() * 100, 3);
        var stddev = Math.Round(rng.NextDouble() * 10 + 0.1, 3);
        var iterations = rng.Next(1000, 100_001);

        return new JsonObject
        {
            ["distribution"] = distribution,
            ["mean"] = mean,
            ["stddev"] = stddev,
            ["iterations"] = iterations
        };
    }

    private static Guid DeterministicGuid(string key)
    {
        Span<byte> hash = stackalloc byte[32];
        SHA256.HashData(Encoding.UTF8.GetBytes(key), hash);
        return new Guid(hash[..16]);
    }
}
