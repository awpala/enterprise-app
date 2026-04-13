using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace EA.Api.IntegrationTests.Infrastructure;

/// <summary>
/// Per-request test authentication handler. Each outbound request opts in to an
/// identity by setting <c>X-Test-User-Oid</c> (plus optional <c>-Tid</c>,
/// <c>-Idp</c>, <c>-Name</c>, <c>-Email</c> siblings). Requests without the Oid
/// header are treated as anonymous so integration tests can exercise the 401
/// negative path. Claim names mirror <c>EA.Api.Auth.DevAuthHandler</c>.
/// </summary>
public sealed class TestAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    /// <summary>
    /// The scheme name registered by the integration test factory.
    /// </summary>
    public const string SchemeName = "Test";

    /// <summary>Request header carrying the <c>oid</c> claim (required to authenticate).</summary>
    public const string OidHeader = "X-Test-User-Oid";

    /// <summary>Request header carrying the <c>tid</c> claim.</summary>
    public const string TidHeader = "X-Test-User-Tid";

    /// <summary>Request header carrying the <c>idp</c> claim.</summary>
    public const string IdpHeader = "X-Test-User-Idp";

    /// <summary>Request header carrying the <c>name</c> claim.</summary>
    public const string NameHeader = "X-Test-User-Name";

    /// <summary>Request header carrying the <c>preferred_username</c> claim.</summary>
    public const string EmailHeader = "X-Test-User-Email";

    /// <inheritdoc />
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(OidHeader, out var oidValues) ||
            string.IsNullOrWhiteSpace(oidValues.ToString()))
        {
            // No header present -> no result, so [Authorize] produces 401.
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        var claims = new List<Claim>
        {
            new("oid", oidValues.ToString()),
        };

        if (Request.Headers.TryGetValue(TidHeader, out var tid) && !string.IsNullOrWhiteSpace(tid.ToString()))
            claims.Add(new Claim("tid", tid.ToString()));

        if (Request.Headers.TryGetValue(IdpHeader, out var idp) && !string.IsNullOrWhiteSpace(idp.ToString()))
            claims.Add(new Claim("idp", idp.ToString()));

        if (Request.Headers.TryGetValue(NameHeader, out var name) && !string.IsNullOrWhiteSpace(name.ToString()))
            claims.Add(new Claim("name", name.ToString()));

        if (Request.Headers.TryGetValue(EmailHeader, out var email) && !string.IsNullOrWhiteSpace(email.ToString()))
            claims.Add(new Claim("preferred_username", email.ToString()));

        var identity = new ClaimsIdentity(claims, SchemeName, nameType: "name", roleType: ClaimTypes.Role);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

/// <summary>
/// Extension helpers for attaching a synthetic principal to outbound integration
/// test requests via <see cref="TestAuthHandler"/>'s header protocol.
/// </summary>
public static class TestAuthHttpClientExtensions
{
    /// <summary>
    /// Stamps the <c>X-Test-User-*</c> default request headers on the supplied
    /// <see cref="HttpClient"/>. Replaces any values previously set so tests can
    /// swap identity mid-fixture without leaking state across requests.
    /// </summary>
    public static HttpClient WithUser(
        this HttpClient client,
        Guid oid,
        Guid tid,
        string idp = "test",
        string? name = null,
        string? email = null)
    {
        client.DefaultRequestHeaders.Remove(TestAuthHandler.OidHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.TidHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.IdpHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.NameHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.EmailHeader);

        client.DefaultRequestHeaders.Add(TestAuthHandler.OidHeader, oid.ToString());
        client.DefaultRequestHeaders.Add(TestAuthHandler.TidHeader, tid.ToString());
        client.DefaultRequestHeaders.Add(TestAuthHandler.IdpHeader, idp);

        if (!string.IsNullOrWhiteSpace(name))
            client.DefaultRequestHeaders.Add(TestAuthHandler.NameHeader, name);

        if (!string.IsNullOrWhiteSpace(email))
            client.DefaultRequestHeaders.Add(TestAuthHandler.EmailHeader, email);

        return client;
    }

    /// <summary>
    /// Removes any previously-attached <c>X-Test-User-*</c> headers so the next
    /// request is treated as anonymous by <see cref="TestAuthHandler"/>.
    /// </summary>
    public static HttpClient WithoutUser(this HttpClient client)
    {
        client.DefaultRequestHeaders.Remove(TestAuthHandler.OidHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.TidHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.IdpHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.NameHeader);
        client.DefaultRequestHeaders.Remove(TestAuthHandler.EmailHeader);
        return client;
    }
}
