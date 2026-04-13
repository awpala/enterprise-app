using System.Text.Json;
using EA.Contracts.Messages;
using EA.Domain.Interfaces;
using EA.Infrastructure.Messaging;
using FluentAssertions;
using MassTransit;
using MassTransit.Testing;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;

namespace EA.Api.Tests.Messaging;

/// <summary>
/// Verifies the MassTransit publish/send filter stamps the
/// <c>x-user-*</c> transport headers from <see cref="ICurrentUser"/>.
/// Uses the in-memory MassTransit test harness to publish a real contract
/// (<see cref="ModelRunRequested"/>) and inspect the received envelope.
/// </summary>
[TestFixture]
public class UserContextPublishFilterTests
{
    [Test]
    public async Task Send_AuthenticatedUser_StampsAllUserHeaders()
    {
        var oid = Guid.NewGuid();
        var tid = Guid.NewGuid();
        var currentUser = new StubCurrentUser
        {
            IsAuthenticated = true,
            Oid = oid,
            Tid = tid,
            Idp = "google.com",
            Name = "Alice Example",
            Email = "alice@example.com",
        };

        await using var provider = BuildProvider(currentUser);
        var harness = provider.GetRequiredService<ITestHarness>();
        await harness.Start();

        var message = NewModelRunRequested();
        await harness.Bus.Publish(message);

        var published = await harness.Published.Any<ModelRunRequested>();
        published.Should().BeTrue();

        var context = harness.Published.Select<ModelRunRequested>().First().Context;
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserOidHeader)
            .Should().Be(oid.ToString());
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserTidHeader)
            .Should().Be(tid.ToString());
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserIdpHeader)
            .Should().Be("google.com");
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserNameHeader)
            .Should().Be("Alice Example");
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserEmailHeader)
            .Should().Be("alice@example.com");
    }

    [Test]
    public async Task Send_WhenNotAuthenticated_DoesNotStampHeaders()
    {
        var currentUser = new StubCurrentUser { IsAuthenticated = false };

        await using var provider = BuildProvider(currentUser);
        var harness = provider.GetRequiredService<ITestHarness>();
        await harness.Start();

        await harness.Bus.Publish(NewModelRunRequested());

        (await harness.Published.Any<ModelRunRequested>()).Should().BeTrue();

        var context = harness.Published.Select<ModelRunRequested>().First().Context;
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserOidHeader)
            .Should().BeNull();
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserTidHeader)
            .Should().BeNull();
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserIdpHeader)
            .Should().BeNull();
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserNameHeader)
            .Should().BeNull();
        context.Headers.Get<string>(UserContextPublishFilter<ModelRunRequested>.UserEmailHeader)
            .Should().BeNull();
    }

    private static ServiceProvider BuildProvider(ICurrentUser currentUser)
    {
        var services = new ServiceCollection();
        services.AddSingleton(currentUser);

        services.AddMassTransitTestHarness(x =>
        {
            x.UsingInMemory((context, cfg) =>
            {
                cfg.UseSendFilter(typeof(UserContextPublishFilter<>), context);
                cfg.UsePublishFilter(typeof(UserContextPublishFilter<>), context);
                cfg.ConfigureEndpoints(context);
            });
        });

        return services.BuildServiceProvider(validateScopes: true);
    }

    private static ModelRunRequested NewModelRunRequested() => new(
        MessageId: Guid.NewGuid(),
        CorrelationId: Guid.NewGuid(),
        OccurredAtUtc: DateTime.UtcNow,
        ModelId: Guid.NewGuid(),
        ModelRunId: Guid.NewGuid(),
        ModelName: "unit-test-model",
        Parameters: (JsonDocument?)null);

    private sealed class StubCurrentUser : ICurrentUser
    {
        public Guid? Oid { get; set; }
        public Guid? Tid { get; set; }
        public string? Idp { get; set; }
        public string? Name { get; set; }
        public string? Email { get; set; }
        public bool IsAuthenticated { get; set; }
    }
}
