using System.Security.Claims;
using EA.Domain.Interfaces;
using Microsoft.AspNetCore.Http;

namespace EA.Api.Auth;

/// <summary>
/// <see cref="IHttpContextAccessor"/>-backed implementation of <see cref="ICurrentUser"/>.
/// Parses Entra External ID claim shapes, including the <c>emails</c> array emitted
/// on ID tokens for local (email-OTP) accounts, and defaults <c>Idp</c> to
/// <c>"email"</c> when the <c>idp</c> claim is absent.
/// </summary>
public sealed class CurrentUser(IHttpContextAccessor httpContextAccessor) : ICurrentUser
{
    private const string OidClaimType = "http://schemas.microsoft.com/identity/claims/objectidentifier";
    private const string TidClaimType = "http://schemas.microsoft.com/identity/claims/tenantid";

    private ClaimsPrincipal? Principal => httpContextAccessor.HttpContext?.User;

    /// <inheritdoc />
    public Guid? Oid
    {
        get
        {
            var raw = Principal?.FindFirst(OidClaimType)?.Value
                      ?? Principal?.FindFirst("oid")?.Value;
            return Guid.TryParse(raw, out var parsed) ? parsed : null;
        }
    }

    /// <inheritdoc />
    public Guid? Tid
    {
        get
        {
            var raw = Principal?.FindFirst(TidClaimType)?.Value
                      ?? Principal?.FindFirst("tid")?.Value;
            return Guid.TryParse(raw, out var parsed) ? parsed : null;
        }
    }

    /// <inheritdoc />
    public string? Idp
    {
        get
        {
            if (Principal is null)
                return null;

            var idp = Principal.FindFirst("idp")?.Value;
            if (!string.IsNullOrWhiteSpace(idp))
                return idp;

            // No idp claim is emitted for local email-OTP accounts in External ID.
            // Only default to "email" when the principal is actually authenticated.
            return Principal.Identity?.IsAuthenticated == true ? "email" : null;
        }
    }

    /// <inheritdoc />
    public string? Name =>
        Principal?.FindFirst("name")?.Value
        ?? Principal?.FindFirst(ClaimTypes.Name)?.Value;

    /// <inheritdoc />
    public string? Email
    {
        get
        {
            if (Principal is null)
                return null;

            // External ID ID tokens carry an "emails" array for local accounts.
            // FindAll returns each value; take the first non-empty entry.
            var emails = Principal.FindFirst("emails")?.Value;
            if (!string.IsNullOrWhiteSpace(emails))
                return emails;

            return Principal.FindFirst("preferred_username")?.Value
                   ?? Principal.FindFirst(ClaimTypes.Email)?.Value;
        }
    }

    /// <inheritdoc />
    public bool IsAuthenticated =>
        httpContextAccessor.HttpContext?.User?.Identity?.IsAuthenticated ?? false;
}
