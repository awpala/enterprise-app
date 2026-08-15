using EA.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace EA.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core entity configuration for the append-only <see cref="AuditEvent"/>
/// table. Rows are emitted by <c>AuditStampingInterceptor</c> during
/// <c>SaveChanges</c> for auditable domain entities.
/// </summary>
public class AuditEventConfiguration : IEntityTypeConfiguration<AuditEvent>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<AuditEvent> builder)
    {
        builder.ToTable("audit_events");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.Id)
            .HasColumnName("id")
            .ValueGeneratedNever();

        builder.Property(e => e.OccurredAtUtc)
            .HasColumnName("occurred_at_utc")
            .IsRequired();

        builder.Property(e => e.ActorSubjectId)
            .HasColumnName("actor_subject_id");

        builder.Property(e => e.ActorTenantId)
            .HasColumnName("actor_tenant_id");

        builder.Property(e => e.ActorName)
            .HasColumnName("actor_name")
            .HasMaxLength(200);

        builder.Property(e => e.ActorEmail)
            .HasColumnName("actor_email")
            .HasMaxLength(200);

        builder.Property(e => e.ActorIdentityProvider)
            .HasColumnName("actor_identity_provider")
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.ActorType)
            .HasColumnName("actor_type")
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.Action)
            .HasColumnName("action")
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.EntityType)
            .HasColumnName("entity_type")
            .IsRequired()
            .HasMaxLength(64);

        builder.Property(e => e.EntityId)
            .HasColumnName("entity_id");

        builder.Property(e => e.Details)
            .HasColumnName("details")
            .HasColumnType("jsonb");

        builder.Property(e => e.CorrelationId)
            .HasColumnName("correlation_id");

        builder.HasIndex(e => new { e.EntityType, e.EntityId })
            .HasDatabaseName("ix_audit_events_entity");

        builder.HasIndex(e => new { e.ActorSubjectId, e.OccurredAtUtc })
            .IsDescending(false, true)
            .HasDatabaseName("ix_audit_events_actor_subject_id_occurred_at_utc");
    }
}
