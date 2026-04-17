namespace EA.Contracts.Models;

/// <summary>
/// Request payload for batch model run execution.
/// </summary>
public record BatchRunRequest(IReadOnlyList<Guid> ModelIds);
