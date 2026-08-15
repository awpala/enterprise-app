using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using EA.Domain.Interfaces;
using Microsoft.AspNetCore.Http;

namespace EA.Api.Auth;

/// <summary>
/// <see cref="IHttpContextAccessor"/>-backed implementation of <see cref="ICurrentUser"/>.
/// Normalizes Entra External ID, Cognito, and standard OIDC claim shapes into
/// the provider-neutral <see cref="ICurrentUser"/> contract.
/// </summary>
public sealed class CurrentUser(IHttpContextAccessor httpContextAccessor) : ICurrentUser
{
    private const string OidClaimType = "http://schemas.microsoft.com/identity/claims/objectidentifier";
    private const string TidClaimType = "http://schemas.microsoft.com/identity/claims/tenantid";

    private ClaimsPrincipal? Principal => httpContextAccessor.HttpContext?.User;

    /// <inheritdoc />
    public Guid? SubjectId
    {
        get
        {
            var raw = Principal?.FindFirst(OidClaimType)?.Value
                      ?? Principal?.FindFirst("oid")?.Value
                      ?? Principal?.FindFirst("sub")?.Value;
            var issuer = Principal?.FindFirst("iss")?.Value ?? string.Empty;
            return ToStableGuid(string.IsNullOrWhiteSpace(raw) ? null : $"{issuer}|{raw}", raw);
        }
    }

    /// <inheritdoc />
    public Guid? TenantId
    {
        get
        {
            var raw = Principal?.FindFirst(TidClaimType)?.Value
                      ?? Principal?.FindFirst("tid")?.Value;
            if (!string.IsNullOrWhiteSpace(raw) && Guid.TryParse(raw, out var parsed))
                return parsed;

            var issuer = Principal?.FindFirst("iss")?.Value;
            return ToStableGuid(issuer, issuer);
        }
    }

    /// <inheritdoc />
    public string? IdentityProvider
    {
        get
        {
            if (Principal is null)
                return null;

            var idp = Principal.FindFirst("idp")?.Value;
            if (!string.IsNullOrWhiteSpace(idp))
                return idp;

            var identities = Principal.FindFirst("identities")?.Value;
            if (!string.IsNullOrWhiteSpace(identities))
            {
                try
                {
                    using var document = JsonDocument.Parse(identities);
                    var first = document.RootElement.ValueKind == JsonValueKind.Array
                        ? document.RootElement.EnumerateArray().FirstOrDefault()
                        : default;
                    if (first.ValueKind == JsonValueKind.Object
                        && first.TryGetProperty("providerName", out var providerName)
                        && providerName.GetString() is { Length: > 0 } federatedProvider)
                        return federatedProvider;
                }
                catch (JsonException)
                {
                    // Malformed optional federation metadata should not reject an
                    // otherwise valid token; fall through to issuer inference.
                }
            }

            var issuer = Principal.FindFirst("iss")?.Value ?? string.Empty;
            if (issuer.Contains("amazonaws.com", StringComparison.OrdinalIgnoreCase))
            {
                // Cognito federated usernames use `<provider>_<subject>`.
                // Native users do not, so preserve `cognito` for that path.
                var username = Principal.FindFirst("cognito:username")?.Value;
                var separator = username?.IndexOf('_') ?? -1;
                return separator > 0 ? username![..separator] : "cognito";
            }

            // If an authenticated principal has no provider metadata, retain a
            // stable provider-neutral fallback instead of returning an empty value.
            return Principal.Identity?.IsAuthenticated == true ? "email" : null;
        }
    }

    /// <inheritdoc />
    public string? Name =>
        Principal?.FindFirst("name")?.Value
        ?? Principal?.FindFirst(ClaimTypes.Name)?.Value
        ?? Principal?.FindFirst("username")?.Value
        ?? Principal?.FindFirst("cognito:username")?.Value;

    /// <inheritdoc />
    public string? Email
    {
        get
        {
            if (Principal is null)
                return null;

            // Prefer the provider's emails claim, then common OIDC email claims.
            var emails = Principal.FindFirst("emails")?.Value;
            if (!string.IsNullOrWhiteSpace(emails))
                return emails;

            return Principal.FindFirst("preferred_username")?.Value
                   ?? Principal.FindFirst("email")?.Value
                   ?? Principal.FindFirst(ClaimTypes.Email)?.Value;
        }
    }

    /// <inheritdoc />
    public bool IsAuthenticated =>
        httpContextAccessor.HttpContext?.User?.Identity?.IsAuthenticated ?? false;

    private static Guid? ToStableGuid(string? value, string? directGuidCandidate)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        if (Guid.TryParse(directGuidCandidate, out var parsed))
            return parsed;

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        Span<byte> bytes = stackalloc byte[16];
        hash.AsSpan(0, 16).CopyTo(bytes);
        bytes[7] = (byte)((bytes[7] & 0x0F) | 0x50);
        bytes[8] = (byte)((bytes[8] & 0x3F) | 0x80);
        return new Guid(bytes);
    }
}
