START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417150000_AddModelRunSampleData') THEN
    ALTER TABLE model_runs ADD sample_data jsonb NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260417150000_AddModelRunSampleData') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260417150000_AddModelRunSampleData', '10.0.5');
    END IF;
END $EF$;

COMMIT;
