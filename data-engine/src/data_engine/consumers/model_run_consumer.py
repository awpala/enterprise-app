"""RabbitMQ consumer for model.run.requested messages.

Listens on a queue bound to the MassTransit message-type exchange and
delegates computation to the metrics workflow.
"""

import json
import logging

import pika
import pika.spec
from pika.adapters.blocking_connection import BlockingChannel

from data_engine.config import Settings
from data_engine.models.messages import MassTransitEnvelope, ModelRunRequested
from data_engine.producers.model_run_producer import ModelRunProducer
from data_engine.topology import (
    EXCHANGE_MODEL_RUN_REQUESTED,
    QUEUE_DATA_ENGINE_MODEL_RUN_REQUESTED,
)
from data_engine.workflows.model_metrics import UnsupportedDistributionError, compute_metrics

logger = logging.getLogger(__name__)


class ModelRunConsumer:
    """Blocking consumer for ModelRunRequested messages."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._connection: pika.BlockingConnection | None = None
        self._channel: BlockingChannel | None = None
        self._producer: ModelRunProducer | None = None
        self._should_stop = False

    def start(self) -> None:
        """Connect to RabbitMQ and start consuming. Blocks until stopped."""
        logger.info(
            "Connecting to RabbitMQ at %s:%d (vhost=%s)",
            self._settings.rabbitmq_host,
            self._settings.rabbitmq_port,
            self._settings.rabbitmq_vhost,
        )

        params = pika.ConnectionParameters(
            host=self._settings.rabbitmq_host,
            port=self._settings.rabbitmq_port,
            virtual_host=self._settings.rabbitmq_vhost,
            credentials=pika.PlainCredentials(
                self._settings.rabbitmq_user,
                self._settings.rabbitmq_password,
            ),
            heartbeat=600,
            blocked_connection_timeout=300,
        )

        # Assign to locals first so the type checker sees non-None types for the
        # rest of this method without repeated None-narrowing.
        connection = pika.BlockingConnection(params)
        self._connection = connection
        channel = connection.channel()
        if channel is None:
            raise RuntimeError("Failed to open RabbitMQ channel")
        self._channel = channel
        self._producer = ModelRunProducer(channel, self._settings)

        logger.info("RabbitMQ connection established, channel opened")

        # Declare the MassTransit message-type exchange (fanout).
        channel.exchange_declare(
            exchange=EXCHANGE_MODEL_RUN_REQUESTED, exchange_type="fanout", durable=True
        )

        # Declare the consumer queue and bind to the exchange.
        channel.queue_declare(queue=QUEUE_DATA_ENGINE_MODEL_RUN_REQUESTED, durable=True)
        channel.queue_bind(
            queue=QUEUE_DATA_ENGINE_MODEL_RUN_REQUESTED,
            exchange=EXCHANGE_MODEL_RUN_REQUESTED,
        )

        channel.basic_qos(prefetch_count=1)
        channel.basic_consume(
            queue=QUEUE_DATA_ENGINE_MODEL_RUN_REQUESTED,
            on_message_callback=self._on_message,
        )

        logger.info(
            "Consuming from queue '%s' (exchange '%s')",
            QUEUE_DATA_ENGINE_MODEL_RUN_REQUESTED,
            EXCHANGE_MODEL_RUN_REQUESTED,
        )
        self._should_stop = False

        while not self._should_stop:
            connection.process_data_events(time_limit=1)

    def stop(self) -> None:
        """Signal the consumer to shut down gracefully."""
        logger.info("Consumer stop requested")
        self._should_stop = True
        channel = self._channel
        if channel is not None and channel.is_open:
            channel.stop_consuming()

    def _on_message(
        self,
        channel: BlockingChannel,
        method: pika.spec.Basic.Deliver,
        _properties: pika.spec.BasicProperties,
        body: bytes,
    ) -> None:
        """Handle an incoming MassTransit envelope."""
        # Initialize before the try block so except clauses have a typed,
        # guaranteed binding rather than relying on locals() inspection.
        payload: ModelRunRequested | None = None
        try:
            raw = json.loads(body)
            envelope = MassTransitEnvelope.model_validate(raw)
            payload = ModelRunRequested.model_validate(envelope.message)

            logger.info(
                "Received message_id=%s correlation_id=%s: processing run %s for model %s (%s)",
                payload.messageId,
                payload.correlationId,
                payload.modelRunId,
                payload.modelId,
                payload.modelName,
            )

            # Narrow _producer to a local so the type checker is satisfied for
            # the duration of this message's processing.
            producer = self._producer
            if producer is None:
                raise RuntimeError("Producer not initialised; start() was not called")

            # 1. Publish started event.
            producer.publish_run_started(
                model_run_id=payload.modelRunId,
                model_id=payload.modelId,
                correlation_id=payload.correlationId,
            )

            # 2. Compute metrics.
            metrics, result_summary, histogram_data = compute_metrics(payload.parameters.model_dump())

            # 3. Publish completed event.
            producer.publish_run_completed(
                model_run_id=payload.modelRunId,
                model_id=payload.modelId,
                correlation_id=payload.correlationId,
                metrics=metrics,
                result_summary=result_summary,
                histogram_data=histogram_data,
            )

            logger.info(
                "Run %s completed with %d metrics (correlation_id=%s)",
                payload.modelRunId,
                len(metrics),
                payload.correlationId,
            )

        except UnsupportedDistributionError as exc:
            logger.warning(
                "Unsupported distribution for run %s (correlation_id=%s): %s",
                payload.modelRunId if payload is not None else "unknown",
                payload.correlationId if payload is not None else "unknown",
                exc,
            )
            if payload is not None and self._producer is not None:
                self._producer.publish_run_failed(
                    model_run_id=payload.modelRunId,
                    model_id=payload.modelId,
                    correlation_id=payload.correlationId,
                    error_message=str(exc),
                )
        except Exception:
            logger.exception(
                "Unexpected error processing message (model_run_id=%s, correlation_id=%s)",
                payload.modelRunId if payload is not None else "unknown",
                payload.correlationId if payload is not None else "unknown",
            )
            if payload is not None and self._producer is not None:
                try:
                    self._producer.publish_run_failed(
                        model_run_id=payload.modelRunId,
                        model_id=payload.modelId,
                        correlation_id=payload.correlationId,
                        error_message="Unexpected processing error",
                    )
                except Exception:
                    logger.exception(
                        "Failed to publish failure event for run %s",
                        payload.modelRunId,
                    )
        finally:
            channel.basic_ack(delivery_tag=method.delivery_tag)
