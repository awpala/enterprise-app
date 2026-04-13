using System.Net;
using System.Net.Http.Json;
using EA.Api.IntegrationTests.Infrastructure;
using EA.Contracts.Models;
using EA.Domain.Entities;
using EA.Infrastructure.Data;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;

namespace EA.Api.IntegrationTests.Audit;

/// <summary>
/// End-to-end checks that the EF <c>AuditStampingInterceptor</c> reads
/// <c>ICurrentUser</c> — populated here from the <c>X-Test-User-*</c> headers
/// parsed by <see cref="TestAuthHandler"/> — and stamps the audit columns on
/// both inserts and updates.
/// </summary>
[TestFixture]
public class AuditStampingTests
{
    private ApiWebApplicationFactory _factory = null!;
    private HttpClient _client = null!;

    [OneTimeSetUp]
    public async Task OneTimeSetUp()
    {
        _factory = new ApiWebApplicationFactory();
        await _factory.InitializeContainersAsync();
        _client = _factory.CreateClient();
    }

    [OneTimeTearDown]
    public async Task OneTimeTearDown()
    {
        _client.Dispose();
        await _factory.DisposeContainersAsync();
        await _factory.DisposeAsync();
    }

    [Test]
    public async Task CreateModel_WithAuthenticatedUser_StampsCreatedByAndName()
    {
        var aliceOid = Guid.NewGuid();
        var aliceTid = Guid.NewGuid();
        _client.WithUser(aliceOid, aliceTid, idp: "test", name: "Alice", email: "alice@example.com");

        var createRequest = new { name = $"audit-create-{Guid.NewGuid():N}" };
        var createResponse = await _client.PostAsJsonAsync("/api/v1/models", createRequest);
        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        var created = await createResponse.Content.ReadFromJsonAsync<ModelDto>();
        created.Should().NotBeNull();

        var stored = await LoadModelAsync(created!.Id);
        stored.Should().NotBeNull();
        stored!.CreatedBy.Should().Be(aliceOid);
        stored.CreatedByName.Should().Be("Alice");
    }

    [Test]
    public async Task UpdateModel_StampsUpdatedByAndName()
    {
        var aliceOid = Guid.NewGuid();
        var bobOid = Guid.NewGuid();
        var tenant = Guid.NewGuid();

        // Alice creates.
        _client.WithUser(aliceOid, tenant, idp: "test", name: "Alice", email: "alice@example.com");
        var createRequest = new { name = $"audit-update-{Guid.NewGuid():N}" };
        var createResponse = await _client.PostAsJsonAsync("/api/v1/models", createRequest);
        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);
        var created = await createResponse.Content.ReadFromJsonAsync<ModelDto>();

        // Bob updates.
        _client.WithUser(bobOid, tenant, idp: "test", name: "Bob", email: "bob@example.com");
        var updateRequest = new { name = "Updated By Bob", description = "desc", status = "Active" };
        var updateResponse = await _client.PutAsJsonAsync($"/api/v1/models/{created!.Id}", updateRequest);
        updateResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        var stored = await LoadModelAsync(created.Id);
        stored.Should().NotBeNull();
        stored!.CreatedBy.Should().Be(aliceOid);
        stored.CreatedByName.Should().Be("Alice");
        stored.UpdatedBy.Should().Be(bobOid);
        stored.UpdatedByName.Should().Be("Bob");
    }

    [Test]
    public async Task CreateModel_WithoutAuth_Returns401()
    {
        _client.WithoutUser();

        var createRequest = new { name = "should-fail" };
        var response = await _client.PostAsJsonAsync("/api/v1/models", createRequest);

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    private async Task<Model?> LoadModelAsync(Guid id)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return await db.Models.AsNoTracking().FirstOrDefaultAsync(m => m.Id == id);
    }
}
