"""Shared test fixtures for the data engine test suite."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from data_engine.models.messages import ModelRunRequested, ModelRunRequestedParameters


@pytest.fixture()
def normal_request() -> ModelRunRequested:
    """A ModelRunRequested with normal distribution parameters."""
    return ModelRunRequested(
        messageId=uuid4(),
        correlationId=uuid4(),
        occurredAtUtc=datetime.now(timezone.utc),
        modelId=uuid4(),
        modelRunId=uuid4(),
        modelName="Test Normal Model",
        parameters=ModelRunRequestedParameters(
            sampleSize=500,
            distribution="normal",
            mean=10.0,
            stdDev=2.0,
        ),
    )


@pytest.fixture()
def uniform_request() -> ModelRunRequested:
    """A ModelRunRequested with uniform distribution parameters."""
    return ModelRunRequested(
        messageId=uuid4(),
        correlationId=uuid4(),
        occurredAtUtc=datetime.now(timezone.utc),
        modelId=uuid4(),
        modelRunId=uuid4(),
        modelName="Test Uniform Model",
        parameters=ModelRunRequestedParameters(
            sampleSize=1000,
            distribution="uniform",
            mean=5.0,
            stdDev=3.0,
        ),
    )
