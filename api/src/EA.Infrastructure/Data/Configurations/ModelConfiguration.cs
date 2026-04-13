using EA.Domain.Entities;
using EA.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace EA.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core entity configuration for the <see cref="Model"/> entity.
/// </summary>
public class ModelConfiguration : IEntityTypeConfiguration<Model>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Model> builder)
    {
        builder.ToTable("models");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(m => m.Name)
            .HasColumnName("name")
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(m => m.Description)
            .HasColumnName("description")
            .HasMaxLength(2000);

        builder.Property(m => m.Status)
            .HasColumnName("status")
            .HasConversion<string>()
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(m => m.Version)
            .HasColumnName("version")
            .IsRequired()
            .HasDefaultValue(1);

        builder.Property(m => m.Parameters)
            .HasColumnName("parameters")
            .HasColumnType("jsonb");

        builder.Property(m => m.CreatedAtUtc)
            .HasColumnName("created_at_utc")
            .IsRequired();

        builder.Property(m => m.UpdatedAtUtc)
            .HasColumnName("updated_at_utc")
            .IsRequired();

        builder.Property(m => m.CreatedBy)
            .HasColumnName("created_by")
            .IsRequired();

        builder.Property(m => m.CreatedByName)
            .HasColumnName("created_by_name")
            .HasMaxLength(200);

        builder.Property(m => m.UpdatedBy)
            .HasColumnName("updated_by");

        builder.Property(m => m.UpdatedByName)
            .HasColumnName("updated_by_name")
            .HasMaxLength(200);

        builder.HasMany(m => m.Runs)
            .WithOne(r => r.Model)
            .HasForeignKey(r => r.ModelId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(m => m.Status)
            .HasDatabaseName("ix_models_status");

        builder.HasIndex(m => m.Name)
            .HasDatabaseName("ix_models_name");
    }
}
