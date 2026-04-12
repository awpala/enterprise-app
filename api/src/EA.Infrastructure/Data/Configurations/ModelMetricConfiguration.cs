using EA.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace EA.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core entity configuration for the <see cref="ModelMetric"/> entity.
/// </summary>
public class ModelMetricConfiguration : IEntityTypeConfiguration<ModelMetric>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<ModelMetric> builder)
    {
        builder.ToTable("model_metrics");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(m => m.ModelRunId)
            .HasColumnName("model_run_id")
            .IsRequired();

        builder.Property(m => m.MetricName)
            .HasColumnName("metric_name")
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(m => m.MetricValue)
            .HasColumnName("metric_value")
            .HasPrecision(18, 6)
            .IsRequired();

        builder.Property(m => m.CalculatedAtUtc)
            .HasColumnName("calculated_at_utc")
            .IsRequired();

        builder.HasIndex(m => m.ModelRunId)
            .HasDatabaseName("ix_model_metrics_model_run_id");
    }
}
