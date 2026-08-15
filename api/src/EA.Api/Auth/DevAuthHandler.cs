using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace EA.Api.Auth;

/// <summary>
/// Authentication handler used when <c>Authentication:Enabled = false</c>.
/// Synthesizes a fixed development principal so local clients can exercise
/// guarded endpoints without contacting an external identity provider.
/// </summary>
public sealed class DevAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    /// <summary>
    /// The scheme name registered in <c>Program.cs</c>.
    /// </summary>
    public const string SchemeName = "Dev";

    /// <summary>
    /// Sentinel object identifier for the development principal.
    /// </summary>
    public static readonly Guid DevOid = new("00000000-0000-0000-0000-000000000001");

    /// <summary>
    /// Sentinel tenant identifier for the dev principal.
    /// </summary>
    public static readonly Guid DevTid = new("00000000-0000-0000-0000-000000000002");

    /// <inheritdoc />
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim("oid", DevOid.ToString()),
            new Claim("tid", DevTid.ToString()),
            new Claim("name", "Dev User"),
            new Claim("idp", "dev"),
            new Claim("preferred_username", "dev@localhost"),
        };

        var identity = new ClaimsIdentity(claims, SchemeName, nameType: "name", roleType: ClaimTypes.Role);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
