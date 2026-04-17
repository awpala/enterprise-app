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
    VALUES ('20260417120000_FixSeedModelParameters', '10.0.5');
    END IF;
END $EF$;

COMMIT;
