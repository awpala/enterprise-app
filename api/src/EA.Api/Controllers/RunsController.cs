using EA.Contracts.Models;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EA.Api.Controllers;

/// <summary>
/// REST API controller for cross-model run operations.
/// Provides a top-level view of runs across all models and batch run capabilities.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/[controller]")]
public class RunsController(
    IModelFacade facade,
    ILogger<RunsController> logger) : ControllerBase
{
    /// <summary>
    /// Retrieves a paged list of runs across all models, optionally filtered by status.
    /// </summary>
    /// <param name="page">Page number (1-based). Defaults to 1.</param>
    /// <param name="pageSize">Number of items per page. Defaults to 20.</param>
    /// <param name="status">Optional run status filter (Pending, Running, Completed, Failed).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A paged list of run summaries with model names.</returns>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<RunSummaryDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAllRuns(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] ModelRunStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        var (items, totalCount) = await facade.GetAllRunsAsync(page, pageSize, status, cancellationToken);

        var dtos = items.Select(r => new RunSummaryDto(
            r.Id,
            r.ModelId,
            r.Model.Name,
            r.Status.ToString(),
            r.RequestedAtUtc,
            r.StartedAtUtc,
            r.CompletedAtUtc,
            r.ErrorMessage)).ToList();

        return Ok(new PagedResult<RunSummaryDto>(dtos, totalCount, page, pageSize));
    }

    /// <summary>
    /// Requests runs for multiple models in a single batch operation.
    /// Uses throttled parallelism (max 5 concurrent) for efficient processing.
    /// </summary>
    /// <param name="request">The batch run request containing model identifiers.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>An array of run summaries for the created runs.</returns>
    [HttpPost("batch")]
    [ProducesResponseType(typeof(IReadOnlyList<RunSummaryDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> RequestBatchRun(
        [FromBody] BatchRunRequest request,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
            return ValidationProblem();

        if (request.ModelIds.Count == 0)
            return BadRequest(new ProblemDetails { Title = "Empty batch", Detail = "At least one model ID is required." });

        logger.LogInformation("Batch run requested for {Count} models", request.ModelIds.Count);

        var runs = await facade.RequestBatchRunAsync(request.ModelIds, cancellationToken);

        // Load model names for the response — runs from RequestModelRunAsync
        // do not have the Model navigation loaded, so we do a follow-up query
        // to get the model names in bulk.
        var modelIds = runs.Select(r => r.ModelId).Distinct().ToHashSet();
        var modelNames = new Dictionary<Guid, string>();
        foreach (var modelId in modelIds)
        {
            var model = await facade.GetModelByIdAsync(modelId, cancellationToken);
            if (model is not null)
            {
                modelNames[modelId] = model.Name;
            }
        }

        var dtos = runs.Select(r => new RunSummaryDto(
            r.Id,
            r.ModelId,
            modelNames.GetValueOrDefault(r.ModelId, "Unknown"),
            r.Status.ToString(),
            r.RequestedAtUtc,
            r.StartedAtUtc,
            r.CompletedAtUtc,
            r.ErrorMessage)).ToList();

        return Ok(dtos);
    }
}
