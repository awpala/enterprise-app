using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace EA.Api.Auth;

/// <summary>
/// Authentication handler used when <c>Authentication:Enabled = true</c> and
/// <c>Authentication:AllowGuest = true</c>. Synthesizes a fixed guest principal
/// when no Bearer token is present. The current authorization model grants that
/// principal the same endpoint access as other authenticated principals.
/// </summary>
public sealed class GuestAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    /// <summary>
    /// The scheme name registered in <c>Program.cs</c>.
    /// </summary>
    public const string SchemeName = "Guest";

    /// <summary>
    /// Sentinel object identifier for the guest principal.
    /// </summary>
    public static readonly Guid GuestOid = new("00000000-0000-0000-0000-000000000003");

    /// <summary>
    /// Sentinel tenant identifier for the guest principal.
    /// </summary>
    public static readonly Guid GuestTid = new("00000000-0000-0000-0000-000000000004");

    /// <inheritdoc />
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim("oid", GuestOid.ToString()),
            new Claim("tid", GuestTid.ToString()),
            new Claim("name", "Guest User"),
            new Claim("idp", "guest"),
            new Claim("preferred_username", "guest@demo"),
        };

        var identity = new ClaimsIdentity(claims, SchemeName, nameType: "name", roleType: ClaimTypes.Role);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
