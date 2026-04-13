using System.Net;
using System.Net.Http.Json;
using EA.Api.IntegrationTests.Infrastructure;
using EA.Contracts.Models;
using FluentAssertions;
using NUnit.Framework;

namespace EA.Api.IntegrationTests;

[TestFixture]
public class ModelsEndpointTests
{
    private ApiWebApplicationFactory _factory = null!;
    private HttpClient _client = null!;

    [OneTimeSetUp]
    public async Task OneTimeSetUp()
    {
        _factory = new ApiWebApplicationFactory();
        await _factory.InitializeContainersAsync();
        _client = _factory.CreateClient();
        // Attach a default synthetic principal so the guarded controller
        // actions exercised by this fixture are authorized. Per-test identity
        // control lives in AuditStampingTests.
        _client.WithUser(
            oid: Guid.NewGuid(),
            tid: Guid.NewGuid(),
            idp: "test",
            name: "Integration Fixture",
            email: "fixture@example.com");
    }

    [OneTimeTearDown]
    public async Task OneTimeTearDown()
    {
        _client.Dispose();
        await _factory.DisposeContainersAsync();
        await _factory.DisposeAsync();
    }

    [Test]
    public async Task GetModels_EmptyDatabase_ReturnsEmptyPage()
    {
        var response = await _client.GetAsync("/api/v1/models");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var result = await response.Content.ReadFromJsonAsync<PagedResult<ModelDto>>();
        result.Should().NotBeNull();
        result!.Items.Should().BeEmpty();
        result.TotalCount.Should().Be(0);
    }

    [Test]
    public async Task CreateModel_ThenGetById_ReturnsCreatedModel()
    {
        var createRequest = new { name = "Integration Test Model", description = "Created by integration test" };
        var createResponse = await _client.PostAsJsonAsync("/api/v1/models", createRequest);
        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        var created = await createResponse.Content.ReadFromJsonAsync<ModelDto>();
        created.Should().NotBeNull();
        created!.Name.Should().Be("Integration Test Model");
        created.Status.Should().Be("Draft");

        var getResponse = await _client.GetAsync($"/api/v1/models/{created.Id}");
        getResponse.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Test]
    public async Task UpdateModel_ValidUpdate_ReturnsUpdatedModel()
    {
        var createRequest = new { name = "To Update" };
        var createResponse = await _client.PostAsJsonAsync("/api/v1/models", createRequest);
        var created = await createResponse.Content.ReadFromJsonAsync<ModelDto>();

        var updateRequest = new { name = "Updated Name", description = "Updated", status = "Active" };
        var updateResponse = await _client.PutAsJsonAsync($"/api/v1/models/{created!.Id}", updateRequest);
        updateResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        var updated = await updateResponse.Content.ReadFromJsonAsync<ModelDto>();
        updated!.Name.Should().Be("Updated Name");
        updated.Status.Should().Be("Active");
        updated.Version.Should().Be(2);
    }

    [Test]
    public async Task DeleteModel_ExistingModel_ReturnsNoContent()
    {
        var createRequest = new { name = "To Delete" };
        var createResponse = await _client.PostAsJsonAsync("/api/v1/models", createRequest);
        var created = await createResponse.Content.ReadFromJsonAsync<ModelDto>();

        var deleteResponse = await _client.DeleteAsync($"/api/v1/models/{created!.Id}");
        deleteResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    [Test]
    public async Task GetModel_NonExistentId_Returns404()
    {
        var response = await _client.GetAsync($"/api/v1/models/{Guid.NewGuid()}");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Test]
    public async Task RequestRun_ExistingModel_ReturnsCreated()
    {
        var createRequest = new { name = "Run Test Model" };
        var createResponse = await _client.PostAsJsonAsync("/api/v1/models", createRequest);
        var created = await createResponse.Content.ReadFromJsonAsync<ModelDto>();

        var runResponse = await _client.PostAsync($"/api/v1/models/{created!.Id}/runs", null);
        runResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        var run = await runResponse.Content.ReadFromJsonAsync<ModelRunDto>();
        run.Should().NotBeNull();
        run!.Status.Should().Be("Pending");
    }

    [Test]
    public async Task HealthLive_Always_ReturnsHealthy()
    {
        var response = await _client.GetAsync("/health/live");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
