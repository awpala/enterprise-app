using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EA.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class NormalizeIdentityColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "actor_tid",
                table: "audit_events",
                newName: "actor_tenant_id");

            migrationBuilder.RenameColumn(
                name: "actor_oid",
                table: "audit_events",
                newName: "actor_subject_id");

            migrationBuilder.RenameColumn(
                name: "actor_idp",
                table: "audit_events",
                newName: "actor_identity_provider");

            migrationBuilder.RenameIndex(
                name: "ix_audit_events_actor_oid_occurred_at_utc",
                table: "audit_events",
                newName: "ix_audit_events_actor_subject_id_occurred_at_utc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "actor_tenant_id",
                table: "audit_events",
                newName: "actor_tid");

            migrationBuilder.RenameColumn(
                name: "actor_subject_id",
                table: "audit_events",
                newName: "actor_oid");

            migrationBuilder.RenameColumn(
                name: "actor_identity_provider",
                table: "audit_events",
                newName: "actor_idp");

            migrationBuilder.RenameIndex(
                name: "ix_audit_events_actor_subject_id_occurred_at_utc",
                table: "audit_events",
                newName: "ix_audit_events_actor_oid_occurred_at_utc");
        }
    }
}
