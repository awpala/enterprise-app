"""RabbitMQ producer for model run lifecycle messages.

Publishes messages wrapped in MassTransit envelope format to the
corresponding message-type exchanges.
"""

import json
import logging
from datetime import datetime, timezone
from uuid import UUID, uuid4

import pika
from pika.adapters.blocking_connection import BlockingChannel

from data_engine.config import Settings
from data_engine.models.messages import (
    MassTransitEnvelope,
    MetricResult,
    ModelRunCompleted,
    ModelRunFailed,
    ModelRunStarted,
    ResultSummary,
)
from data_engine.topology import (
    EXCHANGE_MODEL_RUN_COMPLETED,
    EXCHANGE_MODEL_RUN_FAILED,
    EXCHANGE_MODEL_RUN_STARTED,
    URN_MODEL_RUN_COMPLETED,
    URN_MODEL_RUN_FAILED,
    URN_MODEL_RUN_STARTED,
)

logger = logging.getLogger(__name__)


class ModelRunProducer:
    """Publishes model run lifecycle events to MassTransit exchanges."""

    def __init__(self, channel: BlockingChannel, settings: Settings) -> None:
        self._channel: BlockingChannel = channel
        self._settings = settings

        # Declare all outbound exchanges.
        for exchange_name in [
            EXCHANGE_MODEL_RUN_STARTED,
            EXCHANGE_MODEL_RUN_COMPLETED,
            EXCHANGE_MODEL_RUN_FAILED,
        ]:
            self._channel.exchange_declare(exchange=exchange_name, exchange_type="fanout", durable=True)

    def publish_run_started(
        self,
        model_run_id: UUID,
        model_id: UUID,
        correlation_id: UUID,
    ) -> None:
        """Publish a ModelRunStarted event."""
        payload = ModelRunStarted(
            correlationId=correlation_id,
            modelRunId=model_run_id,
            modelId=model_id,
        )
        self._publish(
            exchange=EXCHANGE_MODEL_RUN_STARTED,
            message_type=URN_MODEL_RUN_STARTED,
            payload=payload.model_dump(mode="json"),
            correlation_id=correlation_id,
        )
        logger.info("Published ModelRunStarted for run %s", model_run_id)

    def publish_run_completed(
        self,
        model_run_id: UUID,
        model_id: UUID,
        correlation_id: UUID,
        metrics: list[MetricResult],
        result_summary: ResultSummary,
    ) -> None:
        """Publish a ModelRunCompleted event."""
        payload = ModelRunCompleted(
            correlationId=correlation_id,
            modelRunId=model_run_id,
            modelId=model_id,
            metrics=metrics,
            resultSummary=result_summary,
        )
        self._publish(
            exchange=EXCHANGE_MODEL_RUN_COMPLETED,
            message_type=URN_MODEL_RUN_COMPLETED,
            payload=payload.model_dump(mode="json"),
            correlation_id=correlation_id,
        )
        logger.info("Published ModelRunCompleted for run %s", model_run_id)

    def publish_run_failed(
        self,
        model_run_id: UUID,
        model_id: UUID,
        correlation_id: UUID,
        error_message: str,
    ) -> None:
        """Publish a ModelRunFailed event."""
        payload = ModelRunFailed(
            correlationId=correlation_id,
            modelRunId=model_run_id,
            modelId=model_id,
            errorMessage=error_message,
        )
        self._publish(
            exchange=EXCHANGE_MODEL_RUN_FAILED,
            message_type=URN_MODEL_RUN_FAILED,
            payload=payload.model_dump(mode="json"),
            correlation_id=correlation_id,
        )
        logger.warning("Published ModelRunFailed for run %s: %s", model_run_id, error_message)

    def _publish(
        self,
        exchange: str,
        message_type: str,
        payload: dict,
        correlation_id: UUID,
    ) -> None:
        """Wrap in MassTransit envelope and publish to the exchange."""
        envelope = MassTransitEnvelope(
            messageId=uuid4(),
            conversationId=correlation_id,
            correlationId=correlation_id,
            messageType=[message_type],
            message=payload,
        )

        body = json.dumps(envelope.model_dump(mode="json"), default=str)
        self._channel.basic_publish(
            exchange=exchange,
            routing_key="",
            body=body.encode("utf-8"),
            properties=pika.BasicProperties(
                content_type="application/json",
                delivery_mode=2,  # persistent
            ),
        )
