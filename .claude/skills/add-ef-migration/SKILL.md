---
name: add-ef-migration
description: Creates a new EF Core migration with proper configuration and review artifacts.
disable-model-invocation: false
---

## Inputs

- **Migration name** (e.g., `AddAnalysisJobsTable`)
- **Schema changes** (new entity, new column, index, relationship change)

## What It Produces

1. **Entity configuration** (if new entity) in `api/src/EA.Infrastructure/Configurations/{Entity}Configuration.cs`
2. **DbSet registration** (if new entity) added to `AppDbContext`
3. **Migration files** generated via `dotnet ef migrations add {Name}`
4. **Idempotent SQL script** generated via `dotnet ef migrations script --idempotent` for review
5. **Down method** verified to be non-empty and correct

## Conventions Applied

- Table names: PascalCase plural
- All entities have `Id` (Guid), `CreatedAtUtc`, `UpdatedAtUtc` (timestamptz)
- Foreign keys named `{Navigation}Id`, indexed automatically
- Soft delete via nullable `DeletedAtUtc` + global query filter
- Enums stored as `text` (Npgsql enum mapping) — never raw integers
- Fluent API configuration in separate `IEntityTypeConfiguration<T>` classes
- String columns have explicit `MaxLength` — no unbounded `nvarchar(max)`
- Review the generated SQL before committing: no data loss, no long locks on large tables
- Never rename or drop columns that exist in shared environments — add new, migrate data, drop later
