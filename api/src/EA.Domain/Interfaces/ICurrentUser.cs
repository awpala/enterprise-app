namespace EA.Domain.Interfaces;

/// <summary>
/// Abstraction over the authenticated principal for the current request.
/// Resolved from the JWT (via <c>IHttpContextAccessor</c>) in production,
/// or a fixed dev principal when <c>AzureAd:Enabled = false</c>.
/// </summary>
/// <remarks>
/// Lives in <c>EA.Domain</c> so infrastructure components (EF Core interceptors,
/// MassTransit filters) can depend on it without taking a reference on the API
/// project. The concrete implementation still lives in <c>EA.Api</c> because
/// that is where <c>HttpContext</c> and claim parsing belong.
/// </remarks>
public interface ICurrentUser
{
    /// <summary>
    /// The Entra object identifier (<c>oid</c> claim), stable within the tenant.
    /// </summary>
    Guid? Oid { get; }

    /// <summary>
    /// The Entra tenant identifier (<c>tid</c> claim).
    /// </summary>
    Guid? Tid { get; }

    /// <summary>
    /// The upstream identity provider. One of <c>"google.com"</c>, <c>"live.com"</c>,
    /// <c>"entra"</c>, <c>"email"</c> (local OTP in External ID where <c>idp</c> is
    /// absent), or <c>"dev"</c> when the dev short-circuit is active.
    /// </summary>
    string? Idp { get; }

    /// <summary>
    /// The display name of the authenticated user (<c>name</c> claim).
    /// </summary>
    string? Name { get; }

    /// <summary>
    /// The email address of the authenticated user. External ID ID tokens may
    /// surface this as the <c>emails</c> array, <c>preferred_username</c>,
    /// or <see cref="System.Security.Claims.ClaimTypes.Email"/>.
    /// </summary>
    string? Email { get; }

    /// <summary>
    /// Whether the current request carries an authenticated principal.
    /// </summary>
    bool IsAuthenticated { get; }
}
