using Azure.Monitor.OpenTelemetry.AspNetCore;
using EA.Api.Auth;
using EA.Contracts.Messages;
using EA.Domain.Interfaces;
using EA.Infrastructure.Consumers;
using EA.Infrastructure.Data;
using EA.Infrastructure.Data.Interceptors;
using EA.Infrastructure.Facades;
using EA.Infrastructure.Messaging;
using EA.Infrastructure.Repositories;
using EA.Infrastructure.Seeding;
using MassTransit;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Identity.Web;
using OpenTelemetry;
using OpenTelemetry.Trace;
using Scalar.AspNetCore;

// ---------------------------------------------------------------------------
// CLI short-circuit: `--seed-generate` regenerates the on-disk seed JSON
// under SeedHostedService.DefaultSeedPath (or the path passed after the flag)
// and exits without building the web host. Typical dev invocation writes to
// /workspace/api/seed so the files land in the repo for commit.
// ---------------------------------------------------------------------------
if (args.Contains("--seed-generate"))
{
    var flagIndex = Array.IndexOf(args, "--seed-generate");
    var outputPath = flagIndex + 1 < args.Length && !args[flagIndex + 1].StartsWith("--", StringComparison.Ordinal)
        ? args[flagIndex + 1]
        : SeedHostedService.DefaultSeedPath;

    Console.WriteLine($"Generating seed data under '{outputPath}'...");
    SeedDataGenerator.Generate(outputPath);
    Console.WriteLine("Seed generation complete.");
    return;
}

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------------------
// Observability — Azure Monitor OpenTelemetry distro
// ---------------------------------------------------------------------------
// When a connection string is configured (Terraform injects
// APPLICATIONINSIGHTS_CONNECTION_STRING as a secret env var in deployed
// envs; AzureMonitor:ConnectionString also works via IConfiguration), the
// distro:
//   - exports ASP.NET Core / HttpClient / SqlClient / EF Core / MassTransit
//     v8 traces automatically (no per-span code needed);
//   - bridges ILogger to App Insights `traces` table;
//   - exports runtime metrics.
// Local (docker compose, `dotnet run`, tests) does not set the connection
// string. The distro does NOT silently no-op in that case — it throws
// InvalidOperationException at host start — so we gate `UseAzureMonitor`
// on connection-string presence and fall back to stdout logging only.
// The `EA.Api.Facade` ActivitySource is registered unconditionally so call
// sites can create custom spans uniformly; spans are simply not exported
// when the distro is skipped.
//
// Sampling: 100% in Development, 20% in non-Dev to control ingestion cost.
// Any outbound MassTransit/HTTP spans respect parent sampling so the
// data-engine traces stay correlated with what the API sampled.
// ---------------------------------------------------------------------------
var azureMonitorConnectionString =
    builder.Configuration["AzureMonitor:ConnectionString"]
    ?? Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");

var otelBuilder = builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing.AddSource("EA.Api.Facade"));

if (!string.IsNullOrWhiteSpace(azureMonitorConnectionString))
{
    otelBuilder.UseAzureMonitor(options =>
    {
        options.SamplingRatio = builder.Environment.IsDevelopment() ? 1.0f : 0.2f;
    });
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
// The AuditStampingInterceptor is scoped (it reads the request-scoped
// ICurrentUser), so the DbContext must resolve it per-request as well. The
// (sp, opts) overload gives us a scoped IServiceProvider from which we can
// pull the interceptor. If ICurrentUser reports IsAuthenticated == false
// (seeder + any non-HTTP path) the interceptor is a no-op.
// ---------------------------------------------------------------------------
builder.Services.AddScoped<AuditStampingInterceptor>();

builder.Services.AddDbContext<AppDbContext>((sp, options) =>
    options
        .UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"))
        .AddInterceptors(sp.GetRequiredService<AuditStampingInterceptor>()));

// ---------------------------------------------------------------------------
// Repositories & Facades
// ---------------------------------------------------------------------------
builder.Services.AddScoped<IModelRepository, ModelRepository>();
builder.Services.AddScoped<IAuditRepository, AuditRepository>();
builder.Services.AddScoped<IModelFacade, ModelFacade>();

// ---------------------------------------------------------------------------
// Seeding
// ---------------------------------------------------------------------------
builder.Services.AddScoped<ModelSeeder>();
builder.Services.AddHostedService<SeedHostedService>();

// ---------------------------------------------------------------------------
// MassTransit + RabbitMQ
// ---------------------------------------------------------------------------
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<ModelRunCompletedConsumer>();
    x.AddConsumer<ModelRunStartedConsumer>();
    x.AddConsumer<ModelRunFailedConsumer>();

    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(builder.Configuration["RabbitMQ:Host"] ?? "localhost", "/", h =>
        {
            h.Username(builder.Configuration["RabbitMQ:Username"] ?? "guest");
            h.Password(builder.Configuration["RabbitMQ:Password"] ?? "guest");
        });

        // ---------------------------------------------------------------------
        // Outbound user-identity propagation
        // ---------------------------------------------------------------------
        // The open-generic UserContextPublishFilter<T> stamps the current
        // HTTP request's principal onto every Send and Publish as transport
        // headers (x-user-oid, x-user-tid, x-user-idp, x-user-name,
        // x-user-email). MassTransit resolves the filter per message from
        // the container, which picks up the request-scoped ICurrentUser.
        // Non-HTTP publish paths (seeder, background services) short-circuit
        // inside the filter when IsAuthenticated == false.
        // ---------------------------------------------------------------------
        cfg.UseSendFilter(typeof(UserContextPublishFilter<>), context);
        cfg.UsePublishFilter(typeof(UserContextPublishFilter<>), context);

        // Queue names must stay in sync with data-engine/src/data_engine/topology.py
        cfg.ReceiveEndpoint("ea.api.model-run-started", e =>
            e.ConfigureConsumer<ModelRunStartedConsumer>(context));

        cfg.ReceiveEndpoint("ea.api.model-run-completed", e =>
            e.ConfigureConsumer<ModelRunCompletedConsumer>(context));

        cfg.ReceiveEndpoint("ea.api.model-run-failed", e =>
            e.ConfigureConsumer<ModelRunFailedConsumer>(context));
    });
});

// ---------------------------------------------------------------------------
// OpenAPI / Scalar
// ---------------------------------------------------------------------------
builder.Services.AddOpenApi();

// ---------------------------------------------------------------------------
// Authentication / Authorization
// ---------------------------------------------------------------------------
// The AzureAd:Enabled flag toggles between real JWT validation against
// Entra External ID (prod + dev containers with envvars) and a fixed
// dev principal (local docker compose + curl workflows + unit tests).
//
// When AzureAd:Enabled=true AND AzureAd:AllowGuest=true (prod-only sales
// demo failsafe), a policy scheme "JwtOrGuest" is registered as the default
// and forwards per-request: requests with an Authorization: Bearer ... header
// go to JwtBearer for real token validation; everything else is handled by
// GuestAuthHandler, which synthesizes a fixed guest principal. Guests get
// the same read/write access as real users — no role scope-down.
// ---------------------------------------------------------------------------
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();

var azureAdEnabled = builder.Configuration.GetValue("AzureAd:Enabled", defaultValue: false);
var allowGuest = builder.Configuration.GetValue("AzureAd:AllowGuest", defaultValue: false);
// allowDev enables the same JwtOrDev policy-scheme trick as allowGuest but
// routes to DevAuthHandler instead. Set AzureAd:AllowDev=true in deployed
// dev so engineers can use the "Log in as Dev" button without a real Entra
// External ID account. Must be false in prod.
var allowDev = builder.Configuration.GetValue("AzureAd:AllowDev", defaultValue: false);

if (azureAdEnabled)
{
    const string jwtOrGuestScheme = "JwtOrGuest";
    const string jwtOrDevScheme = "JwtOrDev";

    // allowDev and allowGuest are mutually exclusive by environment (dev vs prod).
    var defaultScheme = allowDev ? jwtOrDevScheme
        : allowGuest ? jwtOrGuestScheme
        : JwtBearerDefaults.AuthenticationScheme;

    var authBuilder = builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = defaultScheme;
        options.DefaultChallengeScheme = defaultScheme;
    });

    authBuilder.AddMicrosoftIdentityWebApi(
        jwtBearerOptions =>
        {
            builder.Configuration.Bind("AzureAd", jwtBearerOptions);
            jwtBearerOptions.TokenValidationParameters.ValidateIssuer = true;
            jwtBearerOptions.TokenValidationParameters.NameClaimType = "name";
        },
        identityOptions =>
        {
            builder.Configuration.Bind("AzureAd", identityOptions);
        });

    if (allowDev)
    {
        authBuilder.AddScheme<AuthenticationSchemeOptions, DevAuthHandler>(
            DevAuthHandler.SchemeName,
            _ => { });

        authBuilder.AddPolicyScheme(jwtOrDevScheme, jwtOrDevScheme, options =>
        {
            options.ForwardDefaultSelector = ctx =>
            {
                var authHeader = ctx.Request.Headers.Authorization.ToString();
                return authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                    ? JwtBearerDefaults.AuthenticationScheme
                    : DevAuthHandler.SchemeName;
            };
        });
    }

    if (allowGuest)
    {
        authBuilder.AddScheme<AuthenticationSchemeOptions, GuestAuthHandler>(
            GuestAuthHandler.SchemeName,
            _ => { });

        authBuilder.AddPolicyScheme(jwtOrGuestScheme, jwtOrGuestScheme, options =>
        {
            options.ForwardDefaultSelector = ctx =>
            {
                var authHeader = ctx.Request.Headers.Authorization.ToString();
                return authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                    ? JwtBearerDefaults.AuthenticationScheme
                    : GuestAuthHandler.SchemeName;
            };
        });
    }
}
else
{
    builder.Services.AddAuthentication(DevAuthHandler.SchemeName)
        .AddScheme<AuthenticationSchemeOptions, DevAuthHandler>(
            DevAuthHandler.SchemeName,
            _ => { });
}

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();

    options.DefaultPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------
// In Development, allow any http://localhost:* origin so the Angular dev
// server can land on whichever port it picks (4200, 4201, ...).
// In non-Development, only the origins listed under Cors:AllowedOrigins are
// allowed — no wildcard fallback.
// ---------------------------------------------------------------------------
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            policy.SetIsOriginAllowed(origin =>
                    Uri.TryCreate(origin, UriKind.Absolute, out var uri) &&
                    uri.Host == "localhost")
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        }
        else
        {
            var allowedOrigins = builder.Configuration
                .GetSection("Cors:AllowedOrigins")
                .Get<string[]>() ?? [];

            policy.WithOrigins(allowedOrigins)
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        }
    });
});

// ---------------------------------------------------------------------------
// Health checks
// ---------------------------------------------------------------------------
builder.Services.AddHealthChecks()
    .AddNpgSql(builder.Configuration.GetConnectionString("DefaultConnection") ?? string.Empty, name: "postgres");

// ---------------------------------------------------------------------------
// Controllers
// ---------------------------------------------------------------------------
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    });

builder.Services.AddProblemDetails();

var app = builder.Build();

// ---------------------------------------------------------------------------
// Middleware pipeline
// ---------------------------------------------------------------------------
app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();

    // TODO(phase 2A, Scalar OAuth): wire the External ID auth-code + PKCE
    // flow so Scalar's "Try It" can acquire a real Bearer token. Plan
    // budgeted ~half a day for this; leaving a minimal default here so the
    // rest of Phase 2A ships. Config values are already available under
    // AzureAd:Authority / AzureAd:ClientId / AzureAd:Scopes.
    app.MapScalarApiReference(options =>
    {
        options.AddPreferredSecuritySchemes("OAuth2");
    });

    app.UseDeveloperExceptionPage();
}

app.UseCors();

app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false // liveness: always healthy if process is up
}).AllowAnonymous();

app.MapHealthChecks("/health/ready").AllowAnonymous();

app.MapHealthChecks("/health/startup", new HealthCheckOptions
{
    Predicate = _ => false
}).AllowAnonymous();

app.MapControllers();

app.Run();

/// <summary>
/// Partial class to allow integration test WebApplicationFactory access.
/// </summary>
public partial class Program;
