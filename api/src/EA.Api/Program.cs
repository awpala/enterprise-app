using EA.Contracts.Messages;
using EA.Domain.Interfaces;
using EA.Infrastructure.Consumers;
using EA.Infrastructure.Data;
using EA.Infrastructure.Facades;
using EA.Infrastructure.Repositories;
using EA.Infrastructure.Seeding;
using MassTransit;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;

// ---------------------------------------------------------------------------
// CLI short-circuit: `--seed-generate` regenerates the on-disk seed JSON
// under /workspace/seed (or the path passed after the flag) and exits
// without building the web host.
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
// Database
// ---------------------------------------------------------------------------
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// ---------------------------------------------------------------------------
// Repositories & Facades
// ---------------------------------------------------------------------------
builder.Services.AddScoped<IModelRepository, ModelRepository>();
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
    app.MapScalarApiReference();
    app.UseDeveloperExceptionPage();
}

app.UseCors();

app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = _ => false // liveness: always healthy if process is up
});

app.MapHealthChecks("/health/ready");

app.MapHealthChecks("/health/startup", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = _ => false
});

app.MapControllers();

app.Run();

/// <summary>
/// Partial class to allow integration test WebApplicationFactory access.
/// </summary>
public partial class Program;
