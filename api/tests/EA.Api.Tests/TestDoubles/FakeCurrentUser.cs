using EA.Domain.Interfaces;

namespace EA.Api.Tests.TestDoubles;

/// <summary>
/// Hand-rolled <see cref="ICurrentUser"/> stub for controller-level unit tests.
/// All properties are settable so each test can shape the principal it needs.
/// Phase 3 will replace this with per-test principal control inside the
/// integration-test web application factory.
/// </summary>
internal sealed class FakeCurrentUser : ICurrentUser
{
    public Guid? SubjectId { get; set; } = new("00000000-0000-0000-0000-000000000001");
    public Guid? TenantId { get; set; } = new("00000000-0000-0000-0000-000000000002");
    public string? IdentityProvider { get; set; } = "dev";
    public string? Name { get; set; } = "Dev User";
    public string? Email { get; set; } = "dev@localhost";
    public bool IsAuthenticated { get; set; } = true;
}
