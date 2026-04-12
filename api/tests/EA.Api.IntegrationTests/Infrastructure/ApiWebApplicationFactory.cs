using EA.Infrastructure.Data;
using MassTransit;
using MassTransit.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
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
        builder.ConfigureServices(services =>
        {
            // Replace DbContext registration with Testcontainer connection string.
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null)
                services.Remove(descriptor);

            services.AddDbContext<AppDbContext>(options =>
                options.UseNpgsql(_postgres.GetConnectionString()));

            // Replace MassTransit with test harness (no real RabbitMQ needed).
            services.AddMassTransitTestHarness();

            // Ensure the database is created.
            using var scope = services.BuildServiceProvider().CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureCreated();
        });
    }
}
