"""Pydantic v2 models for all message types exchanged via RabbitMQ.

The models mirror the JSON schemas in ``schemas/`` and are compatible with
the MassTransit envelope format used by the .NET API.
"""

from datetime import datetime, timezone
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Shared / Reusable
# ---------------------------------------------------------------------------


class MetricResult(BaseModel):
    """A single named metric with a numeric value."""

    name: str
    value: float


class ResultSummary(BaseModel):
    """Summary information attached to a completed model run."""

    distribution: str
    percentiles: dict[str, float]


# ---------------------------------------------------------------------------
# Inbound: model.run.requested.v1
# ---------------------------------------------------------------------------


class ModelRunRequestedParameters(BaseModel):
    """Parameters block inside a ModelRunRequested message."""

    sampleSize: int = 1000  # noqa: N815 — matches .NET PascalCase JSON
    distribution: str = "normal"
    mean: float = 0.0
    stdDev: float = 1.0  # noqa: N815


class ModelRunRequested(BaseModel):
    """Payload of the ``model.run.requested.v1`` message."""

    messageId: UUID  # noqa: N815
    correlationId: UUID  # noqa: N815
    occurredAtUtc: datetime  # noqa: N815
    modelId: UUID  # noqa: N815
    modelRunId: UUID  # noqa: N815
    modelName: str  # noqa: N815
    parameters: ModelRunRequestedParameters = Field(default_factory=ModelRunRequestedParameters)


# ---------------------------------------------------------------------------
# Outbound: model.run.started.v1
# ---------------------------------------------------------------------------


class ModelRunStarted(BaseModel):
    """Payload of the ``model.run.started.v1`` message."""

    messageId: UUID = Field(default_factory=uuid4)  # noqa: N815
    correlationId: UUID  # noqa: N815
    occurredAtUtc: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))  # noqa: N815
    modelRunId: UUID  # noqa: N815
    modelId: UUID  # noqa: N815


# ---------------------------------------------------------------------------
# Outbound: model.run.completed.v1
# ---------------------------------------------------------------------------


class ModelRunCompleted(BaseModel):
    """Payload of the ``model.run.completed.v1`` message."""

    messageId: UUID = Field(default_factory=uuid4)  # noqa: N815
    correlationId: UUID  # noqa: N815
    occurredAtUtc: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))  # noqa: N815
    modelRunId: UUID  # noqa: N815
    modelId: UUID  # noqa: N815
    metrics: list[MetricResult]
    resultSummary: ResultSummary  # noqa: N815


# ---------------------------------------------------------------------------
# Outbound: model.run.failed.v1
# ---------------------------------------------------------------------------


class ModelRunFailed(BaseModel):
    """Payload of the ``model.run.failed.v1`` message."""

    messageId: UUID = Field(default_factory=uuid4)  # noqa: N815
    correlationId: UUID  # noqa: N815
    occurredAtUtc: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))  # noqa: N815
    modelRunId: UUID  # noqa: N815
    modelId: UUID  # noqa: N815
    errorMessage: str  # noqa: N815


# ---------------------------------------------------------------------------
# MassTransit Envelope
# ---------------------------------------------------------------------------


class MassTransitEnvelope(BaseModel):
    """Wrapper that mirrors the MassTransit JSON envelope structure.

    When publishing, the ``messageType`` list must contain a URN like
    ``urn:message:EA.Contracts.Messages:ModelRunCompleted``.
    """

    messageId: UUID = Field(default_factory=uuid4)  # noqa: N815
    conversationId: UUID | None = None  # noqa: N815
    correlationId: UUID | None = None  # noqa: N815
    messageType: list[str]  # noqa: N815
    message: dict[str, Any]

    # Optional MassTransit headers the .NET side may look for.
    headers: dict[str, str] = Field(default_factory=dict)
