using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EA.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddUserAuditFields : Migration
    {
        // Sentinel Entra oid used to backfill legacy models.created_by rows that
        // were inserted under Phase 2A (free-text creator names). The value is
        // also referenced by the dev auth handler so future audit queries can
        // group "pre-SSO" data cleanly.
        private const string LegacySentinelOid = "00000000-0000-0000-0000-000000000000";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ---- models.created_by: varchar(200) -> uuid, preserve old name ----
            //
            // Cannot ALTER the column in place because existing rows hold
            // human-readable strings. Sequence:
            //   1. add created_by_name and copy the old value over
            //   2. drop the string created_by, add a nullable uuid copy
            //   3. backfill with a sentinel zero-uuid for legacy rows
            //   4. promote to NOT NULL (matches EF model)
            migrationBuilder.AddColumn<string>(
                name: "created_by_name",
                table: "models",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.Sql("UPDATE models SET created_by_name = created_by;");

            migrationBuilder.DropColumn(
                name: "created_by",
                table: "models");

            migrationBuilder.AddColumn<Guid>(
                name: "created_by",
                table: "models",
                type: "uuid",
                nullable: true);

            migrationBuilder.Sql(
                $"UPDATE models SET created_by = '{LegacySentinelOid}' WHERE created_by IS NULL;");

            migrationBuilder.AlterColumn<Guid>(
                name: "created_by",
                table: "models",
                type: "uuid",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            // ---- models: add updated_by / updated_by_name (nullable) ----
            migrationBuilder.AddColumn<Guid>(
                name: "updated_by",
                table: "models",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "updated_by_name",
                table: "models",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            // ---- model_runs: add requested_by / requested_by_name (nullable) ----
            migrationBuilder.AddColumn<Guid>(
                name: "requested_by",
                table: "model_runs",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "requested_by_name",
                table: "model_runs",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            // ---- audit_events: new append-only table ----
            migrationBuilder.CreateTable(
                name: "audit_events",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    occurred_at_utc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    actor_oid = table.Column<Guid>(type: "uuid", nullable: true),
                    actor_tid = table.Column<Guid>(type: "uuid", nullable: true),
                    actor_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    actor_email = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    actor_idp = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    actor_type = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    action = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    entity_type = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    entity_id = table.Column<Guid>(type: "uuid", nullable: true),
                    details = table.Column<string>(type: "jsonb", nullable: false),
                    correlation_id = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_audit_events", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_audit_events_entity",
                table: "audit_events",
                columns: new[] { "entity_type", "entity_id" });

            migrationBuilder.CreateIndex(
                name: "ix_audit_events_actor_oid_occurred_at_utc",
                table: "audit_events",
                columns: new[] { "actor_oid", "occurred_at_utc" },
                descending: new[] { false, true });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "audit_events");

            migrationBuilder.DropColumn(
                name: "requested_by_name",
                table: "model_runs");

            migrationBuilder.DropColumn(
                name: "requested_by",
                table: "model_runs");

            migrationBuilder.DropColumn(
                name: "updated_by_name",
                table: "models");

            migrationBuilder.DropColumn(
                name: "updated_by",
                table: "models");

            // ---- reverse the created_by uuid -> varchar(200) switch ----
            // The pre-migration value is kept in created_by_name for the lifetime
            // of the migration, so Down restores it by copying it back.
            migrationBuilder.DropColumn(
                name: "created_by",
                table: "models");

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                table: "models",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.Sql("UPDATE models SET created_by = COALESCE(created_by_name, 'unknown');");

            migrationBuilder.AlterColumn<string>(
                name: "created_by",
                table: "models",
                type: "character varying(200)",
                maxLength: 200,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(200)",
                oldMaxLength: 200,
                oldNullable: true);

            migrationBuilder.DropColumn(
                name: "created_by_name",
                table: "models");
        }
    }
}
