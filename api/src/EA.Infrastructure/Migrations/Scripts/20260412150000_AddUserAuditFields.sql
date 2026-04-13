START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE models ADD created_by_name character varying(200);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    UPDATE models SET created_by_name = created_by;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE models DROP COLUMN created_by;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE models ADD created_by uuid;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    UPDATE models SET created_by = '00000000-0000-0000-0000-000000000000' WHERE created_by IS NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE models ALTER COLUMN created_by SET NOT NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE models ADD updated_by uuid;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE models ADD updated_by_name character varying(200);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE model_runs ADD requested_by uuid;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    ALTER TABLE model_runs ADD requested_by_name character varying(200);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    CREATE TABLE audit_events (
        id uuid NOT NULL,
        occurred_at_utc timestamp with time zone NOT NULL,
        actor_oid uuid,
        actor_tid uuid,
        actor_name character varying(200),
        actor_email character varying(200),
        actor_idp character varying(100) NOT NULL,
        actor_type character varying(100) NOT NULL,
        action character varying(100) NOT NULL,
        entity_type character varying(64) NOT NULL,
        entity_id uuid,
        details jsonb NOT NULL,
        correlation_id uuid,
        CONSTRAINT "PK_audit_events" PRIMARY KEY (id)
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    CREATE INDEX ix_audit_events_entity ON audit_events (entity_type, entity_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    CREATE INDEX ix_audit_events_actor_oid_occurred_at_utc ON audit_events (actor_oid, occurred_at_utc DESC);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412150000_AddUserAuditFields') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260412150000_AddUserAuditFields', '10.0.5');
    END IF;
END $EF$;

COMMIT;
