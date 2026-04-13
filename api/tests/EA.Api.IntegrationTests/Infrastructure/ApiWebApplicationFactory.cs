using EA.Infrastructure.Data;
using EA.Infrastructure.Data.Interceptors;
using MassTransit;
using MassTransit.Testing;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using NUnit.Framework;
using Testcontainers.PostgreSql;

namespace EA.Api.IntegrationTests.Infrastructure;

/// <summary>
/// Custom WebApplicationFactory that replaces Postgres with a Testcontainer
/// and replaces MassTransit with the in-memory test harness.
/// Uses NUnit lifecycle attributes for container management.
/// </summary>
public class ApiWebApplicationFactory : WebApplicationFactory<Program>
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:16")
        .WithDatabase("test")
        .WithUsername("test")
        .WithPassword("test")
        .Build();

    /// <summary>
    /// Starts the Postgres Testcontainer. Call from [OneTimeSetUp].
    /// </summary>
    public async Task InitializeContainersAsync()
    {
        await _postgres.StartAsync();
    }

    /// <summary>
    /// Stops and disposes the Postgres Testcontainer. Call from [OneTimeTearDown].
    /// </summary>
    public async Task DisposeContainersAsync()
    {
        await _postgres.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Seeding is disabled because the integration tests assert against an
        // empty starting database; the repo seed JSON also targets the
        // /workspace/api/seed path that the Testcontainer doesn't need.
        // AzureAd:Enabled is left false so Program.cs skips the real
        // JwtBearer/Microsoft.Identity.Web wiring; ConfigureServices below
        // replaces the dev short-circuit with a Test scheme that reads the
        // per-request X-Test-User-* headers.
        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["AzureAd:Enabled"] = "false",
                ["Seeding:Enabled"] = "false",
            });
        });

        builder.ConfigureServices(services =>
        {
            // Replace DbContext registration with Testcontainer connection string.
            // Re-wire the AuditStampingInterceptor so audit columns get stamped
            // from ICurrentUser during integration tests, matching production
            // behavior.
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null)
                services.Remove(descriptor);

            services.AddDbContext<AppDbContext>((sp, options) =>
                options
                    .UseNpgsql(_postgres.GetConnectionString())
                    .AddInterceptors(sp.GetRequiredService<AuditStampingInterceptor>()));

            // Replace MassTransit with test harness (no real RabbitMQ needed).
            services.AddMassTransitTestHarness();

            // ---------------------------------------------------------------
            // Replace Program.cs's authentication wiring with the Test scheme.
            // DevAuthHandler is a fixed sentinel; tests need per-request
            // identity control, so we purge all existing auth options +
            // handlers and re-register a single Test scheme as the default.
            // ---------------------------------------------------------------
            services.RemoveAll<IConfigureOptions<AuthenticationOptions>>();
            services.RemoveAll<IPostConfigureOptions<AuthenticationOptions>>();
            services.RemoveAll(typeof(IConfigureOptions<AuthenticationSchemeOptions>));
            services.RemoveAll(typeof(IPostConfigureOptions<AuthenticationSchemeOptions>));

            services
                .AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });

            // Ensure the database is created.
            using var scope = services.BuildServiceProvider().CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureCreated();
        });
    }
}
