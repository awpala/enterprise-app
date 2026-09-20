using EA.Domain.Entities;
using EA.Domain.Enums;
using EA.Infrastructure.Data;
using EA.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Npgsql;
using NUnit.Framework;
using Testcontainers.PostgreSql;

namespace EA.Api.IntegrationTests;

/// <summary>
/// Verifies completion visibility across independent PostgreSQL connections.
/// An explicit EA_TEST_POSTGRES_CONNECTION uses a new disposable database on an
/// existing development server; otherwise the fixture starts a Testcontainer.
/// </summary>
public class ModelRunCompletionTests
{
    private PostgreSqlContainer? _postgres;
    private string? _administrationConnection;
    private string? _databaseName;
    private string _connectionString = string.Empty;

    [OneTimeSetUp]
    public async Task InitializeDatabase()
    {
        _administrationConnection = Environment.GetEnvironmentVariable("EA_TEST_POSTGRES_CONNECTION");
        if (string.IsNullOrWhiteSpace(_administrationConnection))
        {
            _postgres = new PostgreSqlBuilder("postgres:16").Build();
            await _postgres.StartAsync();
            _connectionString = _postgres.GetConnectionString();
        }
        else
        {
            var name = $"ea_completion_test_{Guid.NewGuid():N}";
            await using var connection = new NpgsqlConnection(_administrationConnection);
            await connection.OpenAsync();
            await using var command = new NpgsqlCommand($"CREATE DATABASE {name}", connection);
            await command.ExecuteNonQueryAsync();
            _databaseName = name;
            _connectionString = new NpgsqlConnectionStringBuilder(_administrationConnection)
            {
                Database = name,
                Pooling = false,
            }.ConnectionString;
        }

        await using var db = Database();
        await db.Database.EnsureCreatedAsync();
    }

    [OneTimeTearDown]
    public async Task DisposeDatabase()
    {
        if (_postgres is not null)
            await _postgres.DisposeAsync();
        if (_databaseName is not null)
        {
            await using var connection = new NpgsqlConnection(_administrationConnection);
            await connection.OpenAsync();
            await using var command = new NpgsqlCommand($"DROP DATABASE {_databaseName} WITH (FORCE)", connection);
            await command.ExecuteNonQueryAsync();
        }
    }

    [Test]
    public async Task CompletionRemainsInvisibleUntilMetricsAreSaved()
    {
        var runId = await CreateRun();
        var pause = new PauseMetricsSave();
        await using var writer = Database(pause);
        var completion = new ModelRepository(writer).MarkModelRunCompletedAsync(
            runId, DateTime.UtcNow, null, null, [Metric(runId)]);

        ModelRun duringSave;
        try
        {
            await pause.Entered.Task.WaitAsync(TimeSpan.FromSeconds(10));
            await using var reader = Database();
            duringSave = await reader.ModelRuns.AsNoTracking().Include(run => run.Metrics)
                .SingleAsync(run => run.Id == runId);
        }
        finally
        {
            pause.Release.TrySetResult();
        }

        Assert.That(await completion, Is.True);
        Assert.Multiple(() =>
        {
            Assert.That(duringSave.Status, Is.EqualTo(ModelRunStatus.Pending));
            Assert.That(duringSave.CompletedAtUtc, Is.Null);
            Assert.That(duringSave.Metrics, Is.Empty);
        });

        await using var completedReader = Database();
        var completed = await completedReader.ModelRuns.AsNoTracking().Include(run => run.Metrics)
            .SingleAsync(run => run.Id == runId);
        Assert.Multiple(() =>
        {
            Assert.That(completed.Status, Is.EqualTo(ModelRunStatus.Completed));
            Assert.That(completed.CompletedAtUtc, Is.Not.Null);
            Assert.That(completed.Metrics.Single().MetricValue, Is.EqualTo(1.25m));
        });
    }

    [Test]
    public async Task FailedMetricsSaveDoesNotExposeCompletion()
    {
        var runId = await CreateRun();
        await using var writer = Database(new RejectMetricsSave());
        var repository = new ModelRepository(writer);
        Assert.ThrowsAsync<InvalidOperationException>(async () =>
        {
            await repository.MarkModelRunCompletedAsync(
                runId, DateTime.UtcNow, null, null, [Metric(runId)]);
        });

        await using var reader = Database();
        var run = await reader.ModelRuns.AsNoTracking().Include(value => value.Metrics)
            .SingleAsync(value => value.Id == runId);
        Assert.Multiple(() =>
        {
            Assert.That(run.Status, Is.EqualTo(ModelRunStatus.Pending));
            Assert.That(run.CompletedAtUtc, Is.Null);
            Assert.That(run.Metrics, Is.Empty);
        });
    }

    private AppDbContext Database(params IInterceptor[] interceptors) => new(
        new DbContextOptionsBuilder<AppDbContext>().UseNpgsql(_connectionString)
            .AddInterceptors(interceptors).Options);

    private async Task<Guid> CreateRun()
    {
        await using var db = Database();
        var run = new ModelRun
        {
            Id = Guid.NewGuid(),
            RequestedAtUtc = DateTime.UtcNow,
            Model = new Model
            {
                Id = Guid.NewGuid(), Name = "Completion visibility test",
                CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow,
            },
        };
        db.ModelRuns.Add(run);
        await db.SaveChangesAsync();
        return run.Id;
    }

    private static ModelMetric Metric(Guid runId) => new()
    {
        Id = Guid.NewGuid(), ModelRunId = runId, MetricName = "mean",
        MetricValue = 1.25m, CalculatedAtUtc = DateTime.UtcNow,
    };

    private sealed class PauseMetricsSave : SaveChangesInterceptor
    {
        public TaskCompletionSource Entered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Release { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            Entered.TrySetResult();
            await Release.Task.WaitAsync(cancellationToken);
            return result;
        }
    }

    private sealed class RejectMetricsSave : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result,
            CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("Simulated metrics persistence failure.");
    }
}
