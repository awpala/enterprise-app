using EA.Domain.Entities;
using EA.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace EA.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core entity configuration for the <see cref="ModelRun"/> entity.
/// </summary>
public class ModelRunConfiguration : IEntityTypeConfiguration<ModelRun>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<ModelRun> builder)
    {
        builder.ToTable("model_runs");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(r => r.ModelId)
            .HasColumnName("model_id")
            .IsRequired();

        builder.Property(r => r.Status)
            .HasColumnName("status")
            .HasConversion<string>()
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(r => r.RequestedAtUtc)
            .HasColumnName("requested_at_utc")
            .IsRequired();

        builder.Property(r => r.StartedAtUtc)
            .HasColumnName("started_at_utc");

        builder.Property(r => r.CompletedAtUtc)
            .HasColumnName("completed_at_utc");

        builder.Property(r => r.ResultSummary)
            .HasColumnName("result_summary")
            .HasColumnType("jsonb");

        builder.Property(r => r.ErrorMessage)
            .HasColumnName("error_message")
            .HasMaxLength(4000);

        builder.HasMany(r => r.Metrics)
            .WithOne(m => m.ModelRun)
            .HasForeignKey(m => m.ModelRunId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(r => r.ModelId)
            .HasDatabaseName("ix_model_runs_model_id");

        builder.HasIndex(r => r.Status)
            .HasDatabaseName("ix_model_runs_status");
    }
}
