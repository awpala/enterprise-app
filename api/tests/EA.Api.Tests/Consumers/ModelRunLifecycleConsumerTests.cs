using EA.Contracts.Messages;
using EA.Domain.Entities;
using EA.Domain.Interfaces;
using EA.Infrastructure.Consumers;
using MassTransit;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using NUnit.Framework;

namespace EA.Api.Tests.Consumers;

public class ModelRunLifecycleConsumerTests
{
    [Test]
    public async Task StartedConsumer_UsesAtomicLifecycleUpdate()
    {
        var repository = new Mock<IModelRepository>();
        var message = new ModelRunStarted(Guid.NewGuid(), Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid());
        repository.Setup(value => value.MarkModelRunStartedAsync(message.ModelRunId, message.OccurredAtUtc, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        var context = Context(message);

        await new ModelRunStartedConsumer(repository.Object, NullLogger<ModelRunStartedConsumer>.Instance).Consume(context.Object);

        repository.VerifyAll();
    }

    [Test]
    public async Task CompletedConsumer_SubmitsCompletionAndMetricsTogether()
    {
        var repository = new Mock<IModelRepository>();
        var message = new ModelRunCompleted(
            Guid.NewGuid(), Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(),
            [new MetricResult("mean", 1.25m)], null, null);
        repository.Setup(value => value.MarkModelRunCompletedAsync(
                message.ModelRunId, message.OccurredAtUtc, null, null,
                It.Is<IReadOnlyCollection<ModelMetric>>(metrics => metrics.Count == 1
                    && metrics.Single().ModelRunId == message.ModelRunId
                    && metrics.Single().MetricName == "mean"
                    && metrics.Single().MetricValue == 1.25m),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        var context = Context(message);

        await new ModelRunCompletedConsumer(repository.Object, NullLogger<ModelRunCompletedConsumer>.Instance).Consume(context.Object);

        repository.VerifyAll();
        repository.VerifyNoOtherCalls();
    }

    [Test]
    public async Task FailedConsumer_UsesAtomicTerminalUpdate()
    {
        var repository = new Mock<IModelRepository>();
        var message = new ModelRunFailed(Guid.NewGuid(), Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), Guid.NewGuid(), "failure");
        repository.Setup(value => value.MarkModelRunFailedAsync(
                message.ModelRunId, message.OccurredAtUtc, message.ErrorMessage, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        var context = Context(message);

        await new ModelRunFailedConsumer(repository.Object, NullLogger<ModelRunFailedConsumer>.Instance).Consume(context.Object);

        repository.VerifyAll();
    }

    private static Mock<ConsumeContext<T>> Context<T>(T message) where T : class
    {
        var context = new Mock<ConsumeContext<T>>();
        context.SetupGet(value => value.Message).Returns(message);
        context.SetupGet(value => value.CancellationToken).Returns(CancellationToken.None);
        return context;
    }
}
