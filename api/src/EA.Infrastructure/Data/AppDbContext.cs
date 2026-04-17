using EA.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace EA.Infrastructure.Data;

/// <summary>
/// Application database context for Entity Framework Core.
/// </summary>
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    /// <summary>Gets or sets the models DbSet.</summary>
    public DbSet<Model> Models => Set<Model>();

    /// <summary>Gets or sets the model runs DbSet.</summary>
    public DbSet<ModelRun> ModelRuns => Set<ModelRun>();

    /// <summary>Gets or sets the model metrics DbSet.</summary>
    public DbSet<ModelMetric> ModelMetrics => Set<ModelMetric>();

    /// <summary>Gets or sets the append-only audit events DbSet.</summary>
    public DbSet<AuditEvent> AuditEvents => Set<AuditEvent>();

    /// <inheritdoc />
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
