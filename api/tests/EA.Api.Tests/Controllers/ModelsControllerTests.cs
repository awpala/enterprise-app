using EA.Api.Controllers;
using EA.Domain.Entities;
using EA.Domain.Enums;
using EA.Domain.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using NUnit.Framework;

namespace EA.Api.Tests.Controllers;

[TestFixture]
public class ModelsControllerTests
{
    private Mock<IModelFacade> _facadeMock = null!;
    private Mock<ILogger<ModelsController>> _loggerMock = null!;
    private ModelsController _sut = null!;

    [SetUp]
    public void SetUp()
    {
        _facadeMock = new Mock<IModelFacade>();
        _loggerMock = new Mock<ILogger<ModelsController>>();
        _sut = new ModelsController(_facadeMock.Object, _loggerMock.Object);
    }

    [Test]
    public async Task GetModels_DefaultParameters_ReturnsOkWithPagedResult()
    {
        var models = new List<Model>
        {
            new() { Id = Guid.NewGuid(), Name = "Test Model", Status = ModelStatus.Active, Version = 1, CreatedBy = "test" }
        };
        _facadeMock.Setup(f => f.GetModelsAsync(1, 20, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync((models.AsReadOnly() as IReadOnlyList<Model>, 1));

        var result = await _sut.GetModels();

        result.Should().BeOfType<OkObjectResult>();
    }

    [Test]
    public async Task GetModel_WhenNotFound_ReturnsNotFound()
    {
        _facadeMock.Setup(f => f.GetModelByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((Model?)null);

        var result = await _sut.GetModel(Guid.NewGuid(), CancellationToken.None);

        result.Should().BeOfType<NotFoundResult>();
    }

    [Test]
    public async Task GetModel_WhenFound_ReturnsOk()
    {
        var model = new Model
        {
            Id = Guid.NewGuid(),
            Name = "Test",
            Status = ModelStatus.Draft,
            Version = 1,
            CreatedBy = "test",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };
        _facadeMock.Setup(f => f.GetModelByIdAsync(model.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(model);

        var result = await _sut.GetModel(model.Id, CancellationToken.None);

        result.Should().BeOfType<OkObjectResult>();
    }

    [Test]
    public async Task DeleteModel_WhenFound_ReturnsNoContent()
    {
        _facadeMock.Setup(f => f.ArchiveModelAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var result = await _sut.DeleteModel(Guid.NewGuid(), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
    }

    [Test]
    public async Task DeleteModel_WhenNotFound_ReturnsNotFound()
    {
        _facadeMock.Setup(f => f.ArchiveModelAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var result = await _sut.DeleteModel(Guid.NewGuid(), CancellationToken.None);

        result.Should().BeOfType<NotFoundResult>();
    }

    [Test]
    public async Task RequestRun_WhenModelNotFound_ReturnsNotFound()
    {
        _facadeMock.Setup(f => f.RequestModelRunAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((ModelRun?)null);

        var result = await _sut.RequestRun(Guid.NewGuid(), CancellationToken.None);

        result.Should().BeOfType<NotFoundResult>();
    }

    [Test]
    public async Task RequestRun_WhenModelExists_ReturnsCreated()
    {
        var run = new ModelRun
        {
            Id = Guid.NewGuid(),
            ModelId = Guid.NewGuid(),
            Status = ModelRunStatus.Pending,
            RequestedAtUtc = DateTime.UtcNow
        };
        _facadeMock.Setup(f => f.RequestModelRunAsync(run.ModelId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(run);

        var result = await _sut.RequestRun(run.ModelId, CancellationToken.None);

        result.Should().BeOfType<CreatedAtActionResult>();
    }
}
