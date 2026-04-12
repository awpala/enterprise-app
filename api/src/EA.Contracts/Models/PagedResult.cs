namespace EA.Contracts.Models;

/// <summary>
/// Generic paged result wrapper for list endpoints.
/// </summary>
/// <typeparam name="T">The type of items in the result.</typeparam>
public record PagedResult<T>(
    IReadOnlyList<T> Items,
    int TotalCount,
    int Page,
    int PageSize)
{
    /// <summary>Gets the total number of pages.</summary>
    public int TotalPages => PageSize > 0 ? (int)Math.Ceiling((double)TotalCount / PageSize) : 0;

    /// <summary>Gets whether there is a next page.</summary>
    public bool HasNextPage => Page < TotalPages;

    /// <summary>Gets whether there is a previous page.</summary>
    public bool HasPreviousPage => Page > 1;
}
