using EA.Contracts.Messages;
using EA.Domain.Interfaces;
using EA.Infrastructure.Consumers;
using EA.Infrastructure.Data;
using EA.Infrastructure.Facades;
using EA.Infrastructure.Repositories;
using MassTransit;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;

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
// CORS (development)
// ---------------------------------------------------------------------------
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:4200")
              .AllowAnyHeader()
              .AllowAnyMethod();
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
