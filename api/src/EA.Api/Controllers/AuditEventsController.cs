using EA.Contracts.Models;
using EA.Domain.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EA.Api.Controllers;

/// <summary>
/// REST API controller for querying append-only audit events.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/audit-events")]
public class AuditEventsController(
    IAuditRepository auditRepository,
    ILogger<AuditEventsController> logger) : ControllerBase
{
    /// <summary>
    /// Retrieves a paged list of audit events, optionally filtered by entity type,
    /// entity identifier, or normalized actor subject identifier.
    /// </summary>
    /// <param name="page">Page number (1-based). Defaults to 1.</param>
    /// <param name="pageSize">Number of items per page. Defaults to 20.</param>
    /// <param name="entityType">Optional filter by entity type (e.g. "Model", "ModelRun").</param>
    /// <param name="entityId">Optional filter by entity identifier.</param>
    /// <param name="actorSubjectId">Optional filter by normalized actor subject identifier.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A paged list of audit events.</returns>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<AuditEventDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAuditEvents(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? entityType = null,
        [FromQuery] Guid? entityId = null,
        [FromQuery] Guid? actorSubjectId = null,
        CancellationToken cancellationToken = default)
    {
        logger.LogInformation(
            "Querying audit events: page={Page}, pageSize={PageSize}, entityType={EntityType}, entityId={EntityId}, actorSubjectId={ActorSubjectId}",
            page, pageSize, entityType, entityId, actorSubjectId);

        var (items, totalCount) = await auditRepository.GetAuditEventsAsync(
            page, pageSize, entityType, entityId, actorSubjectId, cancellationToken);

        var dtos = items.Select(e => new AuditEventDto(
            e.Id,
            e.OccurredAtUtc,
            e.ActorSubjectId,
            e.ActorName,
            e.ActorEmail,
            e.ActorIdentityProvider,
            e.ActorType,
            e.Action,
            e.EntityType,
            e.EntityId,
            e.Details,
            e.CorrelationId)).ToList();

        return Ok(new PagedResult<AuditEventDto>(dtos, totalCount, page, pageSize));
    }
}
