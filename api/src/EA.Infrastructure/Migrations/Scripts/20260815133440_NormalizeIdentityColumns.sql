CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE TABLE models (
        id uuid NOT NULL,
        name character varying(200) NOT NULL,
        description character varying(2000),
        status character varying(50) NOT NULL,
        version integer NOT NULL DEFAULT 1,
        parameters jsonb,
        created_at_utc timestamp with time zone NOT NULL,
        updated_at_utc timestamp with time zone NOT NULL,
        created_by character varying(200) NOT NULL,
        CONSTRAINT "PK_models" PRIMARY KEY (id)
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE TABLE model_runs (
        id uuid NOT NULL,
        model_id uuid NOT NULL,
        status character varying(50) NOT NULL,
        requested_at_utc timestamp with time zone NOT NULL,
        started_at_utc timestamp with time zone,
        completed_at_utc timestamp with time zone,
        result_summary jsonb,
        error_message character varying(4000),
        CONSTRAINT "PK_model_runs" PRIMARY KEY (id),
        CONSTRAINT "FK_model_runs_models_model_id" FOREIGN KEY (model_id) REFERENCES models (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE TABLE model_metrics (
        id uuid NOT NULL,
        model_run_id uuid NOT NULL,
        metric_name character varying(200) NOT NULL,
        metric_value numeric(18,6) NOT NULL,
        calculated_at_utc timestamp with time zone NOT NULL,
        CONSTRAINT "PK_model_metrics" PRIMARY KEY (id),
        CONSTRAINT "FK_model_metrics_model_runs_model_run_id" FOREIGN KEY (model_run_id) REFERENCES model_runs (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE INDEX ix_model_metrics_model_run_id ON model_metrics (model_run_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE INDEX ix_model_runs_model_id ON model_runs (model_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE INDEX ix_model_runs_status ON model_runs (status);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE INDEX ix_models_name ON models (name);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    CREATE INDEX ix_models_status ON models (status);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260412143913_InitialCreate') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260412143913_InitialCreate', '10.0.11');
    END IF;
END $EF$;
COMMIT;
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
    VALUES ('20260412150000_AddUserAuditFields', '10.0.11');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417120000_FixSeedModelParameters') THEN
    UPDATE models
    SET parameters = (parameters - 'iterations') || jsonb_build_object('sampleSize', parameters->'iterations')
    WHERE parameters ? 'iterations';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417120000_FixSeedModelParameters') THEN
    UPDATE models
    SET parameters = (parameters - 'stddev') || jsonb_build_object('stdDev', parameters->'stddev')
    WHERE parameters ? 'stddev';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417120000_FixSeedModelParameters') THEN
    UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"exponential"')
    WHERE id = '0afe4fa5-8d61-ada3-1ce8-6eb499110160' AND parameters->>'distribution' = 'triangular';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417120000_FixSeedModelParameters') THEN
    UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"uniform"')
    WHERE id = 'fcbd585c-38ee-7a75-b384-81199f8523a1' AND parameters->>'distribution' = 'triangular';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417120000_FixSeedModelParameters') THEN
    UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"normal"')
    WHERE id = 'ecbcd2fb-6c1c-cef6-2b65-8a206d84872a' AND parameters->>'distribution' = 'triangular';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417120000_FixSeedModelParameters') THEN
    UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"lognormal"')
    WHERE id = '25295baf-d6bd-3d4c-59ce-9c4204821482' AND parameters->>'distribution' = 'triangular';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417120000_FixSeedModelParameters') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260417120000_FixSeedModelParameters', '10.0.11');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417150000_AddModelRunSampleData') THEN
    ALTER TABLE model_runs ADD sample_data jsonb;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417150000_AddModelRunSampleData') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260417150000_AddModelRunSampleData', '10.0.11');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417182133_ChangeAuditDetailsToJsonDocument') THEN
    ALTER TABLE audit_events ALTER COLUMN details DROP NOT NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417182133_ChangeAuditDetailsToJsonDocument') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260417182133_ChangeAuditDetailsToJsonDocument', '10.0.11');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815133440_NormalizeIdentityColumns') THEN
    ALTER TABLE audit_events RENAME COLUMN actor_tid TO actor_tenant_id;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815133440_NormalizeIdentityColumns') THEN
    ALTER TABLE audit_events RENAME COLUMN actor_oid TO actor_subject_id;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815133440_NormalizeIdentityColumns') THEN
    ALTER TABLE audit_events RENAME COLUMN actor_idp TO actor_identity_provider;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815133440_NormalizeIdentityColumns') THEN
    ALTER INDEX ix_audit_events_actor_oid_occurred_at_utc RENAME TO ix_audit_events_actor_subject_id_occurred_at_utc;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260815133440_NormalizeIdentityColumns') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260815133440_NormalizeIdentityColumns', '10.0.11');
    END IF;
END $EF$;
COMMIT;
