using EA.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace EA.Infrastructure.Seeding;

/// <summary>
/// <see cref="IHostedService"/> that conditionally invokes <see cref="ModelSeeder"/>
/// once during application startup. The seeder applies migrations before reading
/// seed files.
/// </summary>
public sealed class SeedHostedService(
    IServiceProvider serviceProvider,
    IConfiguration configuration,
    ILogger<SeedHostedService> logger) : IHostedService
{
    /// <summary>
    /// Default seed root path when <c>Seeding:SeedPath</c> is not configured.
    /// Resolves to <c>{AppContext.BaseDirectory}/seed</c>, matching the deployed
    /// image layout. Local configuration can override it with the repository's
    /// seed directory.
    /// </summary>
    public static readonly string DefaultSeedPath = Path.Combine(AppContext.BaseDirectory, "seed");

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
