using EA.Domain.Entities;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using EA.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace EA.Infrastructure.Repositories;

/// <summary>
/// EF Core implementation of <see cref="IModelRepository"/>.
/// </summary>
public class ModelRepository(AppDbContext dbContext) : IModelRepository
{
    /// <inheritdoc />
    public async Task<(IReadOnlyList<Model> Items, int TotalCount)> GetModelsAsync(
        int page,
        int pageSize,
        ModelStatus? status,
        CancellationToken cancellationToken = default)
    {
        var query = dbContext.Models.AsNoTracking().AsQueryable();

        if (status.HasValue)
        {
            query = query.Where(m => m.Status == status.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(m => m.CreatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    /// <inheritdoc />
    public async Task<Model?> GetModelByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await dbContext.Models
            .Include(m => m.Runs.OrderByDescending(r => r.RequestedAtUtc).Take(1))
            .FirstOrDefaultAsync(m => m.Id == id, cancellationToken);
    }

    /// <inheritdoc />
    public async Task AddModelAsync(Model model, CancellationToken cancellationToken = default)
    {
        await dbContext.Models.AddAsync(model, cancellationToken);
    }

    /// <inheritdoc />
    public Task UpdateModelAsync(Model model, CancellationToken cancellationToken = default)
    {
        dbContext.Models.Update(model);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public async Task<ModelRun?> GetModelRunByIdAsync(Guid runId, CancellationToken cancellationToken = default)
    {
        return await dbContext.ModelRuns
            .Include(r => r.Metrics)
            .FirstOrDefaultAsync(r => r.Id == runId, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<ModelRun>> GetModelRunsAsync(Guid modelId, CancellationToken cancellationToken = default)
    {
        return await dbContext.ModelRuns
            .AsNoTracking()
            .Where(r => r.ModelId == modelId)
            .OrderByDescending(r => r.RequestedAtUtc)
            .ToListAsync(cancellationToken);
    }

    /// <inheritdoc />
    public async Task<(IReadOnlyList<ModelRun> Items, int TotalCount)> GetAllRunsAsync(
        int page, int pageSize, ModelRunStatus? status, CancellationToken cancellationToken = default)
    {
        var query = dbContext.ModelRuns
            .AsNoTracking()
            .Include(r => r.Model)
            .AsQueryable();

        if (status.HasValue)
        {
            query = query.Where(r => r.Status == status.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(r => r.RequestedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    /// <inheritdoc />
    public async Task AddModelRunAsync(ModelRun run, CancellationToken cancellationToken = default)
    {
        await dbContext.ModelRuns.AddAsync(run, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<bool> MarkModelRunStartedAsync(
        Guid runId,
        DateTime startedAtUtc,
        CancellationToken cancellationToken = default)
    {
        var affected = await dbContext.ModelRuns
            .Where(run => run.Id == runId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(
                    run => run.StartedAtUtc,
                    run => run.StartedAtUtc == null || startedAtUtc < run.StartedAtUtc
                        ? startedAtUtc
                        : run.StartedAtUtc)
                .SetProperty(
                    run => run.Status,
                    run => run.Status == ModelRunStatus.Pending
                        ? ModelRunStatus.Running
                        : run.Status),
                cancellationToken);

        return affected > 0;
    }

    /// <inheritdoc />
    public async Task<bool> MarkModelRunCompletedAsync(
        Guid runId,
        DateTime completedAtUtc,
        System.Text.Json.JsonDocument? resultSummary,
        System.Text.Json.JsonDocument? sampleData,
        CancellationToken cancellationToken = default)
    {
        var affected = await dbContext.ModelRuns
            .Where(run => run.Id == runId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(run => run.Status, ModelRunStatus.Completed)
                .SetProperty(run => run.StartedAtUtc, run => run.StartedAtUtc ?? completedAtUtc)
                .SetProperty(run => run.CompletedAtUtc, completedAtUtc)
                .SetProperty(run => run.ResultSummary, resultSummary)
                .SetProperty(run => run.SampleData, sampleData),
                cancellationToken);

        return affected > 0;
    }

    /// <inheritdoc />
    public async Task<bool> MarkModelRunFailedAsync(
        Guid runId,
        DateTime completedAtUtc,
        string errorMessage,
        CancellationToken cancellationToken = default)
    {
        var affected = await dbContext.ModelRuns
            .Where(run => run.Id == runId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(run => run.Status, ModelRunStatus.Failed)
                .SetProperty(run => run.StartedAtUtc, run => run.StartedAtUtc ?? completedAtUtc)
                .SetProperty(run => run.CompletedAtUtc, completedAtUtc)
                .SetProperty(run => run.ErrorMessage, errorMessage),
                cancellationToken);

        return affected > 0;
    }

    /// <inheritdoc />
    public async Task AddModelMetricsAsync(IEnumerable<ModelMetric> metrics, CancellationToken cancellationToken = default)
    {
        await dbContext.ModelMetrics.AddRangeAsync(metrics, cancellationToken);
    }

    /// <inheritdoc />
    public async Task SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    /// <inheritdoc />
    public async Task<bool> ModelExistsAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await dbContext.Models
            .AsNoTracking()
            .AnyAsync(m => m.Id == id && m.Status != ModelStatus.Archived, cancellationToken);
    }
}
