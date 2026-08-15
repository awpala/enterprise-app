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
using OpenTelemetry;
using OpenTelemetry.Metrics;
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
// Observability — cloud-neutral OpenTelemetry with deployment adapters
// ---------------------------------------------------------------------------
// Instrumentation stays cloud-neutral. The deployment selects one exporter:
// Azure Monitor, OTLP (for ADOT or any collector), or none for local/tests.
// Azure's connection string remains an adapter input, not an application-wide
// configuration contract.
// ---------------------------------------------------------------------------
var azureMonitorConnectionString =
    builder.Configuration["AzureMonitor:ConnectionString"]
    ?? Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");

var observabilityExporter = builder.Configuration["Observability:Exporter"]?.Trim().ToLowerInvariant()
    ?? "none";

var otelBuilder = builder.Services.AddOpenTelemetry();

if (observabilityExporter == "azuremonitor")
{
    if (string.IsNullOrWhiteSpace(azureMonitorConnectionString))
        throw new InvalidOperationException(
            "Observability:Exporter is 'azuremonitor' but no Application Insights connection string is configured.");

    otelBuilder.UseAzureMonitor(options =>
    {
        options.SamplingRatio = builder.Environment.IsDevelopment() ? 1.0f : 0.2f;
    });
}
else
{
    otelBuilder
        .WithTracing(tracing =>
        {
            tracing
                .AddSource("EA.Api.Facade")
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation();

            if (observabilityExporter == "otlp")
                tracing.AddOtlpExporter();
        })
        .WithMetrics(metrics =>
        {
            metrics
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation();

            if (observabilityExporter == "otlp")
                metrics.AddOtlpExporter();
        });
}

if (observabilityExporter is not ("azuremonitor" or "otlp" or "none"))
    throw new InvalidOperationException(
        $"Unsupported Observability:Exporter '{observabilityExporter}'. Expected azuremonitor, otlp, or none.");

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
        // headers (x-user-subject, x-user-tenant, x-user-identity-provider, x-user-name,
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
// Authentication uses one deployment-neutral OIDC contract. Terraform selects
// Entra External ID for Azure or Cognito for AWS and supplies normalized values.
//
// When Authentication:Enabled=true AND Authentication:AllowGuest=true, a
// policy scheme "JwtOrGuest" is registered as the default
// and forwards per-request: requests with an Authorization: Bearer ... header
// go to JwtBearer for real token validation; everything else is handled by
// GuestAuthHandler, which synthesizes a fixed guest principal. Guests get
// the same read/write access as real users — no role scope-down.
// ---------------------------------------------------------------------------
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();

var authentication = builder.Configuration.GetSection("Authentication");
var authenticationEnabled = authentication.GetValue("Enabled", defaultValue: false);
var authenticationProvider = authentication["Provider"]?.Trim().ToLowerInvariant() ?? string.Empty;
var allowGuest = authentication.GetValue("AllowGuest", defaultValue: false);
// allowDev enables the same JwtOrDev policy-scheme trick as allowGuest but
// routes to DevAuthHandler instead. Set Authentication:AllowDev=true in deployed
// dev so engineers can use the "Log in as Dev" button without a real external
// identity account. Must be false in production.
var allowDev = authentication.GetValue("AllowDev", defaultValue: false);

if (allowDev && allowGuest)
    throw new InvalidOperationException(
        "Authentication:AllowDev and Authentication:AllowGuest cannot both be enabled.");

if (authenticationEnabled)
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

    var authority = authentication["Authority"]
        ?? throw new InvalidOperationException("Authentication:Authority is required when authentication is enabled.");
    var audience = authentication["Audience"]
        ?? throw new InvalidOperationException("Authentication:Audience is required when authentication is enabled.");
    var clientId = authentication["ClientId"] ?? audience;
    var requiredScope = authentication["RequiredScope"];
    var isCognito = authenticationProvider == "cognito";

    if (authenticationProvider is not ("entra" or "cognito"))
        throw new InvalidOperationException(
            $"Unsupported Authentication:Provider '{authenticationProvider}'. Expected entra or cognito.");

    authBuilder.AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
    {
        options.Authority = authority;
        options.Audience = audience;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidateIssuer = true;
        options.TokenValidationParameters.ValidateLifetime = true;
        options.TokenValidationParameters.ValidateAudience = !isCognito;
        options.TokenValidationParameters.NameClaimType = "name";
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                var principal = context.Principal;
                if (isCognito)
                {
                    var tokenUse = principal?.FindFirst("token_use")?.Value;
                    var tokenClientId = principal?.FindFirst("client_id")?.Value;
                    if (tokenUse != "access" || !string.Equals(tokenClientId, clientId, StringComparison.Ordinal))
                    {
                        context.Fail("The Cognito token is not an access token for this application client.");
                        return Task.CompletedTask;
                    }
                }

                if (!string.IsNullOrWhiteSpace(requiredScope))
                {
                    var scopes = (principal?.FindFirst("scp")?.Value
                                  ?? principal?.FindFirst("scope")?.Value
                                  ?? string.Empty)
                        .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                    if (!scopes.Contains(requiredScope, StringComparer.Ordinal))
                        context.Fail("The access token does not contain the required API scope.");
                }

                return Task.CompletedTask;
            }
        };
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
// In Development, allow any http://localhost:* origin so the Next.js dev
// server can land on whichever port it picks (3000).
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

    // Scalar advertises the preferred OAuth2 security scheme. Interactive
    // token acquisition is intentionally not configured here; callers supply
    // a token issued through the application's browser OIDC flow.
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
