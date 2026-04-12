using EA.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace EA.Infrastructure.Seeding;

/// <summary>
/// <see cref="IHostedService"/> that runs <see cref="ModelSeeder"/> exactly once
/// on application startup, after the DbContext has been migrated.
/// </summary>
public sealed class SeedHostedService(
    IServiceProvider serviceProvider,
    IConfiguration configuration,
    ILogger<SeedHostedService> logger) : IHostedService
{
    /// <summary>Default seed root path when <c>Seeding:SeedPath</c> is not configured.</summary>
    public const string DefaultSeedPath = "/workspace/seed";

    /// <inheritdoc />
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        var enabled = bool.TryParse(configuration["Seeding:Enabled"], out var e) && e;
        if (!enabled)
        {
            logger.LogInformation("Seeding disabled (Seeding:Enabled=false); skipping startup seed.");
            return;
        }

        var seedPath = configuration["Seeding:SeedPath"] ?? DefaultSeedPath;
        logger.LogInformation("Startup seeding enabled; using seed path {SeedPath}.", seedPath);

        using var scope = serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var seeder = scope.ServiceProvider.GetRequiredService<ModelSeeder>();

        try
        {
            await seeder.SeedAsync(db, seedPath, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Startup seeding failed; application will continue.");
        }
    }

    /// <inheritdoc />
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
