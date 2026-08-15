---
name: add-ef-migration
description: Creates a new EF Core migration with proper configuration and review artifacts.
disable-model-invocation: false
---

## Inputs

- **Migration name** (for example, `AddModelRunSampleData`)
- **Schema changes** (new entity, new column, index, relationship change)

## What It Produces

1. **Entity configuration** (if new entity) in `api/src/EA.Infrastructure/Data/Configurations/{Entity}Configuration.cs`
2. **DbSet registration** (if new entity) added to `AppDbContext`
3. **Migration files** generated via `dotnet ef migrations add {Name}`
4. **Idempotent SQL script** generated via `dotnet ef migrations script --idempotent`, written to `api/src/EA.Infrastructure/Migrations/Scripts/{timestamp}_{Name}.sql` so it pairs 1:1 with the C# migration of the same stem (e.g. `20260412143913_InitialCreate.sql` next to `20260412143913_InitialCreate.cs`)
5. **Down method** verified to be non-empty and correct

## Conventions Applied

- Table and column names use explicit plural `snake_case` mappings.
- Domain IDs are application-assigned `Guid` values unless an existing entity establishes a different rule.
- Add only the timestamps and audit fields required by the domain; map UTC `DateTime` values to PostgreSQL `timestamp with time zone`.
- Foreign keys use `{Navigation}Id` in C# and explicit `snake_case` column mappings; add indexes deliberately.
- Models archive through `ModelStatus.Archived`; do not introduce a generic `DeletedAtUtc` convention.
- Enums stored as `text` (Npgsql enum mapping) — never raw integers
- Fluent API configuration in separate `IEntityTypeConfiguration<T>` classes
- String columns have explicit `MaxLength` where the domain has a bounded value.
- Idempotent SQL script is committed at `Migrations/Scripts/{stem}.sql` next to its C# migration — one file per migration, not a rolling aggregate
- Review the generated SQL before committing: no data loss, no long locks on large tables
- Never rename or drop columns that exist in shared environments — add new, migrate data, drop later
