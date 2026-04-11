---
name: scaffold-api-endpoint
description: Creates a new REST API endpoint following project conventions.
disable-model-invocation: false
---

## Inputs

- **Resource name** (e.g., `AnalysisJob`)
- **Operations** (e.g., `CRUD`, `read-only`, or specific list)
- **Domain properties** (e.g., `DatasetId: Guid, Status: string, Parameters: object?`)

## What It Produces

1. **Domain entity** in `api/src/Demo.Domain/Entities/{Resource}.cs` — record or class with properties
2. **EF configuration** in `api/src/Demo.Infrastructure/Configurations/{Resource}Configuration.cs` — fluent API mapping
3. **DTOs** in `api/src/Demo.Contracts/` — `Create{Resource}Request`, `Update{Resource}Request`, `{Resource}Response` as records
4. **Endpoint group** in `api/src/Demo.Api/Endpoints/{Resource}Endpoints.cs` — minimal API `MapGroup` with versioned routes
5. **DbSet registration** added to `AppDbContext`
6. **Migration** created via `dotnet ef migrations add Add{Resource}`

## Conventions Applied

- Routes: `/api/v1/{resource-name-kebab-case}`
- DTOs are records with `init` properties
- POST returns `201 Created` with `Location` header
- GET collection supports pagination (`?page=1&pageSize=20`)
- All endpoints return `ProblemDetails` on error
- OpenAPI annotations on every endpoint (`WithName`, `WithTags`, `Produces`)
- `CreatedAtUtc` / `UpdatedAtUtc` auto-populated via EF `SaveChanges` override
