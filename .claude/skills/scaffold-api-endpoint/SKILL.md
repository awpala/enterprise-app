---
name: scaffold-api-endpoint
description: Creates a new REST API endpoint following project conventions.
disable-model-invocation: false
---

## Inputs

- **Resource name** (for example, `ModelMetric`)
- **Operations** (for example, `CRUD`, `read-only`, or a specific list)
- **Domain properties** (for example, `ModelRunId: Guid`, `MetricName: string`, and `MetricValue: decimal`)

## What It Produces

1. **Domain entity** in `api/src/EA.Domain/Entities/{Resource}.cs` — record or class with properties
2. **EF configuration** in `api/src/EA.Infrastructure/Data/Configurations/{Resource}Configuration.cs` — fluent API mapping
3. **DTOs** in `api/src/EA.Contracts/Models/` — request and response records
4. **Controller** in `api/src/EA.Api/Controllers/{Resources}Controller.cs` with versioned routes
5. **DbSet registration** added to `AppDbContext`
6. **Migration** created via `dotnet ef migrations add Add{Resource}`

## Conventions Applied

- Routes follow the existing controller convention under `/api/v1/{resources}`.
- DTOs are records with `init` properties
- POST returns `201 Created` with `Location` header
- GET collection supports pagination (`?page=1&pageSize=20`)
- All endpoints return `ProblemDetails` on error
- Controller actions use XML documentation and `[ProducesResponseType]` metadata for OpenAPI/Scalar.
- Controllers delegate business behavior to a facade; repositories own persistence.
- IDs and domain timestamps are assigned explicitly by the facade. The EF interceptor stamps authenticated-user audit fields, not timestamps.
