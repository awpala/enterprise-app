using EA.Contracts.Models;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EA.Api.Controllers;

/// <summary>
/// REST API controller for Model CRUD operations and Model Run management.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/[controller]")]
public class ModelsController(
    IModelFacade facade,
    ICurrentUser currentUser,
    ILogger<ModelsController> logger) : ControllerBase
{
    /// <summary>
    /// Retrieves a paged list of models, optionally filtered by status.
    /// </summary>
    /// <param name="page">Page number (1-based). Defaults to 1.</param>
    /// <param name="pageSize">Number of items per page. Defaults to 20.</param>
    /// <param name="status">Optional status filter (Draft, Active, Archived).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A paged list of model summaries.</returns>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<ModelDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetModels(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] ModelStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        var (items, totalCount) = await facade.GetModelsAsync(page, pageSize, status, cancellationToken);

        var dtos = items.Select(m => new ModelDto(
            m.Id, m.Name, m.Description, m.Status.ToString(),
            m.Version, m.CreatedAtUtc, m.UpdatedAtUtc, FormatCreatedBy(m.CreatedByName, m.CreatedBy))).ToList();

        return Ok(new PagedResult<ModelDto>(dtos, totalCount, page, pageSize));
    }

    /// <summary>
    /// Retrieves a model by its unique identifier.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The model detail including the latest run summary.</returns>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ModelDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetModel(Guid id, CancellationToken cancellationToken)
    {
        var model = await facade.GetModelByIdAsync(id, cancellationToken);
        if (model is null)
            return NotFound();

        var latestRun = model.Runs.MaxBy(r => r.RequestedAtUtc);
        ModelRunDto? latestRunDto = latestRun is null ? null : new ModelRunDto(
            latestRun.Id, latestRun.ModelId, latestRun.Status.ToString(),
            latestRun.RequestedAtUtc, latestRun.StartedAtUtc, latestRun.CompletedAtUtc,
            latestRun.ErrorMessage);

        var dto = new ModelDetailDto(
            model.Id, model.Name, model.Description, model.Status.ToString(),
            model.Version, model.Parameters,
            model.CreatedAtUtc, model.UpdatedAtUtc, FormatCreatedBy(model.CreatedByName, model.CreatedBy), latestRunDto);

        return Ok(dto);
    }

    /// <summary>
    /// Creates a new model.
    /// </summary>
    /// <param name="request">The creation payload.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The newly created model.</returns>
    [HttpPost]
    [ProducesResponseType(typeof(ModelDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateModel([FromBody] CreateModelRequest request, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
            return ValidationProblem();

        logger.LogInformation("Creating model with name {ModelName}", request.Name);

        // Pass Guid.Empty / null; the AuditStampingInterceptor fills the audit
        // columns from ICurrentUser before SaveChanges. Seeder call sites pass
        // explicit non-default values so the interceptor leaves them alone.
        var createdBy = currentUser.SubjectId ?? Guid.Empty;
        var createdByName = currentUser.Name;

        var model = await facade.CreateModelAsync(
            request.Name, request.Description, request.Parameters, createdBy, createdByName, cancellationToken);

        var dto = new ModelDto(
            model.Id, model.Name, model.Description, model.Status.ToString(),
            model.Version, model.CreatedAtUtc, model.UpdatedAtUtc, FormatCreatedBy(model.CreatedByName, model.CreatedBy));

        return CreatedAtAction(nameof(GetModel), new { id = model.Id }, dto);
    }

    /// <summary>
    /// Updates an existing model. Increments the version number.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="request">The update payload.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The updated model.</returns>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(ModelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateModel(Guid id, [FromBody] UpdateModelRequest request, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
            return ValidationProblem();

        if (!Enum.TryParse<ModelStatus>(request.Status, true, out var parsedStatus))
            return BadRequest(new ProblemDetails { Title = "Invalid status", Detail = $"'{request.Status}' is not a valid status." });

        logger.LogInformation("Updating model {ModelId} with status {Status}", id, request.Status);

        var model = await facade.UpdateModelAsync(
            id, request.Name, request.Description, parsedStatus, request.Parameters, cancellationToken);

        if (model is null)
        {
            logger.LogWarning("Update failed: model {ModelId} not found or archived", id);
            return NotFound();
        }

        var dto = new ModelDto(
            model.Id, model.Name, model.Description, model.Status.ToString(),
            model.Version, model.CreatedAtUtc, model.UpdatedAtUtc, FormatCreatedBy(model.CreatedByName, model.CreatedBy));

        return Ok(dto);
    }

    /// <summary>
    /// Soft-deletes a model by setting its status to Archived.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteModel(Guid id, CancellationToken cancellationToken)
    {
        logger.LogInformation("Archiving model {ModelId}", id);

        var archived = await facade.ArchiveModelAsync(id, cancellationToken);
        if (!archived)
        {
            logger.LogWarning("Archive failed: model {ModelId} not found", id);
            return NotFound();
        }

        return NoContent();
    }

    /// <summary>
    /// Requests a new run for the specified model. Publishes a message to RabbitMQ.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The newly created model run.</returns>
    [HttpPost("{id:guid}/runs")]
    [ProducesResponseType(typeof(ModelRunDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RequestRun(Guid id, CancellationToken cancellationToken)
    {
        logger.LogInformation("Requesting run for model {ModelId}", id);

        var run = await facade.RequestModelRunAsync(id, cancellationToken);
        if (run is null)
        {
            logger.LogWarning("Run request failed: model {ModelId} not found or archived", id);
            return NotFound();
        }

        var dto = new ModelRunDto(
            run.Id, run.ModelId, run.Status.ToString(),
            run.RequestedAtUtc, run.StartedAtUtc, run.CompletedAtUtc, run.ErrorMessage);

        return CreatedAtAction(nameof(GetRun), new { id, runId = run.Id }, dto);
    }

    /// <summary>
    /// Retrieves all runs for a given model, ordered by most recent first.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A list of model run summaries.</returns>
    [HttpGet("{id:guid}/runs")]
    [ProducesResponseType(typeof(IReadOnlyList<ModelRunDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetRuns(Guid id, CancellationToken cancellationToken)
    {
        var runs = await facade.GetModelRunsAsync(id, cancellationToken);

        var dtos = runs.Select(r => new ModelRunDto(
            r.Id, r.ModelId, r.Status.ToString(),
            r.RequestedAtUtc, r.StartedAtUtc, r.CompletedAtUtc, r.ErrorMessage)).ToList();

        return Ok(dtos);
    }

    /// <summary>
    /// Retrieves a specific model run by its identifier, including computed metrics.
    /// </summary>
    /// <param name="id">The model identifier.</param>
    /// <param name="runId">The run identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The run detail with metrics.</returns>
    [HttpGet("{id:guid}/runs/{runId:guid}")]
    [ProducesResponseType(typeof(ModelRunDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetRun(Guid id, Guid runId, CancellationToken cancellationToken)
    {
        var run = await facade.GetModelRunByIdAsync(id, runId, cancellationToken);
        if (run is null)
            return NotFound();

        var metricDtos = run.Metrics.Select(m => new ModelMetricDto(
            m.Id, m.MetricName, m.MetricValue, m.CalculatedAtUtc)).ToList();

        var dto = new ModelRunDetailDto(
            run.Id, run.ModelId, run.Status.ToString(),
            run.RequestedAtUtc, run.StartedAtUtc, run.CompletedAtUtc,
            run.ResultSummary, run.ErrorMessage, metricDtos, run.SampleData);

        return Ok(dto);
    }

    /// <summary>
    /// Renders the creation-audit columns as a single string for the wire format.
    /// Prefers the captured display name; falls back to the normalized
    /// subject identifier for rows created by principals with no name claim.
    /// </summary>
    private static string FormatCreatedBy(string? createdByName, Guid createdBy) =>
        !string.IsNullOrWhiteSpace(createdByName)
            ? createdByName
            : createdBy == Guid.Empty ? "unknown" : createdBy.ToString();
}
