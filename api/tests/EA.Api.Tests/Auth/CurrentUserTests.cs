using System.Security.Claims;
using EA.Api.Auth;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Moq;
using NUnit.Framework;

namespace EA.Api.Tests.Auth;

/// <summary>
/// Claim-parsing tests for <see cref="CurrentUser"/>. Exercises the External ID
/// claim shapes — including the <c>idp</c>-absent local-account path — that
/// Phase 2A documented as the <see cref="Domain.Interfaces.ICurrentUser.Idp"/>
/// fallback contract.
/// </summary>
[TestFixture]
public class CurrentUserTests
{
    [Test]
    public void Idp_WhenClaimAbsent_DefaultsToEmail()
    {
        // Authenticated principal (IsAuthenticated == true via scheme name) but
        // no "idp" claim — the local email-OTP path in External ID.
        var principal = BuildPrincipal(
            isAuthenticated: true,
            new Claim("oid", Guid.NewGuid().ToString()));

        var sut = BuildSut(principal);

        sut.Idp.Should().Be("email");
    }

    [Test]
    public void Oid_ParsesGuidFromClaim()
    {
        var expected = Guid.NewGuid();
        var principal = BuildPrincipal(
            isAuthenticated: true,
            new Claim("oid", expected.ToString()));

        var sut = BuildSut(principal);

        sut.Oid.Should().Be(expected);
    }

    [Test]
    public void IsAuthenticated_FalseWhenNoUser()
    {
        // Empty principal: no identity, no claims, no HttpContext.User flag.
        var principal = new ClaimsPrincipal(new ClaimsIdentity());
        var sut = BuildSut(principal);

        sut.IsAuthenticated.Should().BeFalse();
    }

    private static ClaimsPrincipal BuildPrincipal(bool isAuthenticated, params Claim[] claims)
    {
        // A ClaimsIdentity is authenticated iff its AuthenticationType is non-null
        // and non-empty. Supplying "Test" mirrors the behaviour of any real
        // handler-minted identity; passing null models an anonymous request.
        var identity = isAuthenticated
            ? new ClaimsIdentity(claims, authenticationType: "Test")
            : new ClaimsIdentity(claims);
        return new ClaimsPrincipal(identity);
    }

    private static CurrentUser BuildSut(ClaimsPrincipal principal)
    {
        var context = new DefaultHttpContext { User = principal };
        var accessor = new Mock<IHttpContextAccessor>();
        accessor.SetupGet(a => a.HttpContext).Returns(context);
        return new CurrentUser(accessor.Object);
    }
}
