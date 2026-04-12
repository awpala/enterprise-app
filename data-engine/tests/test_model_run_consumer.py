"""Tests for message parsing and consumer logic."""

import json
from datetime import datetime, timezone
from uuid import uuid4

from data_engine.models.messages import (
    MassTransitEnvelope,
    ModelRunRequested,
    ModelRunRequestedParameters,
)


class TestMassTransitEnvelopeParsing:
    """Tests for parsing MassTransit envelope format."""

    def test_parse_envelope_with_model_run_requested(self) -> None:
        payload = ModelRunRequested(
            messageId=uuid4(),
            correlationId=uuid4(),
            occurredAtUtc=datetime.now(timezone.utc),
            modelId=uuid4(),
            modelRunId=uuid4(),
            modelName="Test Model",
            parameters=ModelRunRequestedParameters(
                sampleSize=100,
                distribution="normal",
                mean=5.0,
                stdDev=1.0,
            ),
        )

        envelope_data = {
            "messageId": str(uuid4()),
            "conversationId": str(payload.correlationId),
            "correlationId": str(payload.correlationId),
            "messageType": ["urn:message:EA.Contracts.Messages:ModelRunRequested"],
            "message": json.loads(payload.model_dump_json()),
        }

        envelope = MassTransitEnvelope.model_validate(envelope_data)
        parsed = ModelRunRequested.model_validate(envelope.message)

        assert parsed.modelName == "Test Model"
        assert parsed.parameters.sampleSize == 100
        assert parsed.parameters.distribution == "normal"

    def test_envelope_default_parameters(self) -> None:
        message = {
            "messageId": str(uuid4()),
            "correlationId": str(uuid4()),
            "occurredAtUtc": datetime.now(timezone.utc).isoformat(),
            "modelId": str(uuid4()),
            "modelRunId": str(uuid4()),
            "modelName": "Default Params",
        }

        envelope_data = {
            "messageId": str(uuid4()),
            "messageType": ["urn:message:EA.Contracts.Messages:ModelRunRequested"],
            "message": message,
        }

        envelope = MassTransitEnvelope.model_validate(envelope_data)
        parsed = ModelRunRequested.model_validate(envelope.message)

        assert parsed.parameters.sampleSize == 1000
        assert parsed.parameters.distribution == "normal"


class TestModelRunRequestedModel:
    """Tests for the ModelRunRequested Pydantic model."""

    def test_round_trip_serialization(self) -> None:
        original = ModelRunRequested(
            messageId=uuid4(),
            correlationId=uuid4(),
            occurredAtUtc=datetime.now(timezone.utc),
            modelId=uuid4(),
            modelRunId=uuid4(),
            modelName="Round Trip",
        )

        json_str = original.model_dump_json()
        restored = ModelRunRequested.model_validate_json(json_str)

        assert restored.messageId == original.messageId
        assert restored.modelName == "Round Trip"
