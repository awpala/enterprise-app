---
name: add-docker-service
description: Creates a Dockerfile and Compose service entry for a new application component.
disable-model-invocation: true
---

## Inputs

- **Service name** (e.g., `api`, `worker`, `ui`)
- **Technology** (e.g., `.NET 10`, `Angular 20`, `Python 3.12`)
- **Exposed ports** (e.g., `8000`)
- **Dependencies** (e.g., `postgres`, `rabbitmq`)

## What It Produces

1. **Dockerfile** at `{project-folder}/Dockerfile` — multi-stage build
2. **`.dockerignore`** at `{project-folder}/.dockerignore`
3. **Compose service** entry added to `deploy/compose.yaml`
4. **Environment variables** wired in Compose matching production config key names

## Multi-Stage Build Templates

### .NET 10
- Build: `mcr.microsoft.com/dotnet/sdk:10.0` → `dotnet restore` → `dotnet publish`
- Runtime: `mcr.microsoft.com/dotnet/aspnet:10.0`, non-root user, port 8000

### Angular 20
- Build: `node:22` → `npm ci` → `npm run build`
- Runtime: `nginx:alpine`, copy `dist/` to `/usr/share/nginx/html`

### Python
- Runtime: `python:3.12-slim`, non-root user, `pip install --no-cache-dir`

## Conventions Applied

- Copy dependency manifests first for layer caching
- Create and switch to non-root user in runtime stage
- Pin base image versions (never `latest`)
- `ENV ASPNETCORE_URLS=http://0.0.0.0:8000` for .NET services
- `ENV PYTHONUNBUFFERED=1` for Python services
- Compose: use `depends_on` for startup ordering, named volumes for data persistence
- Compose environment variables use same keys as production (different values)
