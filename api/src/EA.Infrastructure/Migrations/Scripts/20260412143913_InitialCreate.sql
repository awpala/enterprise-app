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
    VALUES ('20260412143913_InitialCreate', '10.0.5');
    END IF;
END $EF$;
COMMIT;

