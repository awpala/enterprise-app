"""Entry point for the EA Data Engine service.

Starts the RabbitMQ consumer and blocks until a shutdown signal is received.
"""

import logging
import signal
import sys
import time

from data_engine.config import Settings, load_settings
from data_engine.consumers.model_run_consumer import ModelRunConsumer

logger = logging.getLogger(__name__)


def _configure_logging(settings: Settings) -> None:
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)-8s [%(name)s] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S%z",
        stream=sys.stdout,
    )


def _configure_telemetry(settings: Settings) -> None:
    """Configure the deployment-selected OpenTelemetry exporter adapter."""
    if settings.observability_exporter == "none":
        return

    from opentelemetry.instrumentation.pika import PikaInstrumentor

    if settings.observability_exporter == "azuremonitor":
        from azure.monitor.opentelemetry import configure_azure_monitor

        configure_azure_monitor(
            logger_name="data_engine",
            enable_live_metrics=False,
        )
    else:
        from opentelemetry import metrics, trace
        from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
        from opentelemetry.sdk.metrics import MeterProvider
        from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor

        resource = Resource.create({"service.name": "ea-data-engine"})
        tracer_provider = TracerProvider(resource=resource)
        tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
        trace.set_tracer_provider(tracer_provider)

        metric_reader = PeriodicExportingMetricReader(OTLPMetricExporter())
        metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))

    PikaInstrumentor().instrument()


def main() -> None:
    """Bootstrap and run the data engine consumer."""
    settings = load_settings()
    _configure_logging(settings)
    _configure_telemetry(settings)

    logger.info("Starting EA Data Engine")
    logger.info("RabbitMQ host: %s:%d", settings.rabbitmq_host, settings.rabbitmq_port)

    consumer = ModelRunConsumer(settings)

    # Graceful shutdown on SIGINT / SIGTERM.
    def _shutdown(signum: int, _frame: object) -> None:
        sig_name = signal.Signals(signum).name
        logger.info("Received %s, shutting down gracefully", sig_name)
        consumer.stop()

    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    # Connect with exponential backoff retry.
    delay = settings.reconnect_delay_initial
    while True:
        try:
            consumer.start()
            break  # clean exit after consumer.stop()
        except KeyboardInterrupt:
            logger.info("Interrupted, exiting")
            break
        except Exception:
            logger.exception("Consumer crashed, reconnecting in %.1fs", delay)
            time.sleep(delay)
            delay = min(delay * settings.reconnect_delay_multiplier, settings.reconnect_delay_max)

    logger.info("EA Data Engine stopped")


if __name__ == "__main__":
    main()
