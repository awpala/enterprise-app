using System.Security.Claims;
using EA.Api.Auth;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Moq;
using NUnit.Framework;

namespace EA.Api.Tests.Auth;

/// <summary>
/// Claim-parsing tests for the provider-neutral <see cref="CurrentUser"/> adapter.
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

        sut.IdentityProvider.Should().Be("email");
    }

    [Test]
    public void SubjectId_PreservesGuidFromEntraObjectClaim()
    {
        var expected = Guid.NewGuid();
        var principal = BuildPrincipal(
            isAuthenticated: true,
            new Claim("oid", expected.ToString()));

        var sut = BuildSut(principal);

        sut.SubjectId.Should().Be(expected);
    }

    [Test]
    public void CognitoClaims_MapToStableSubjectTenantAndProvider()
    {
        var principal = BuildPrincipal(
            isAuthenticated: true,
            new Claim("sub", "cognito-subject-123"),
            new Claim("iss", "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_example"),
            new Claim("cognito:username", "native-user"));

        var first = BuildSut(principal);
        var second = BuildSut(principal);

        first.SubjectId.Should().NotBeNull();
        first.SubjectId.Should().Be(second.SubjectId);
        first.TenantId.Should().NotBeNull();
        first.IdentityProvider.Should().Be("cognito");
        first.Name.Should().Be("native-user");
    }

    [Test]
    public void CognitoFederatedUsername_IdentifiesUpstreamProvider()
    {
        var principal = BuildPrincipal(
            isAuthenticated: true,
            new Claim("sub", "federated-subject"),
            new Claim("iss", "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_example"),
            new Claim("cognito:username", "Google_123456"));

        BuildSut(principal).IdentityProvider.Should().Be("Google");
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
        // and non-empty. Supplying "Test" mirrors the behavior of any real
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
