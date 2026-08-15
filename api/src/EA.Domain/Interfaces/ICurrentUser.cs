namespace EA.Domain.Interfaces;

/// <summary>
/// Abstraction over the authenticated principal for the current request.
/// The principal may come from a validated OIDC access token or from an
/// explicitly enabled synthetic development or guest authentication scheme.
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
    /// Stable application identifier derived from the provider subject claim.
    /// Native UUID/GUID subjects are preserved; other OIDC subjects are mapped
    /// deterministically so the domain does not depend on a provider claim shape.
    /// </summary>
    Guid? SubjectId { get; }

    /// <summary>
    /// Stable tenant/issuer identifier. Entra <c>tid</c> values are preserved;
    /// providers without tenant GUIDs are mapped deterministically from issuer.
    /// </summary>
    Guid? TenantId { get; }

    /// <summary>
    /// The upstream identity provider, normalized from Entra <c>idp</c>, Cognito
    /// federation metadata, or a provider-neutral fallback for authenticated
    /// principals without provider metadata.
    /// </summary>
    string? IdentityProvider { get; }

    /// <summary>
    /// The display name of the authenticated user (<c>name</c> claim).
    /// </summary>
    string? Name { get; }

    /// <summary>
    /// The email address of the authenticated user, normalized from common OIDC
    /// and Entra claim shapes.
    /// </summary>
    string? Email { get; }

    /// <summary>
    /// Whether the current request carries an authenticated principal.
    /// </summary>
    bool IsAuthenticated { get; }
}
