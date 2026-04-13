"""Entry point for the EA Data Engine service.

Starts the RabbitMQ consumer and blocks until a shutdown signal is received.
"""

import logging
import os
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


def main() -> None:
    """Bootstrap and run the data engine consumer."""
    # Ordered at the top of main() -- must run BEFORE any logger is used so the
    # AzureMonitor handler is attached to the root logger ahead of log records.
    # Conditional on the env var being set: local docker-compose does not set
    # APPLICATIONINSIGHTS_CONNECTION_STRING, and configure_azure_monitor() would
    # raise without one. Imports are lazy so local dev + unit tests don't need
    # these packages installed.
    if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
        from azure.monitor.opentelemetry import configure_azure_monitor
        from opentelemetry.instrumentation.pika import PikaInstrumentor

        configure_azure_monitor(
            logger_name="data_engine",
            enable_live_metrics=False,
        )
        PikaInstrumentor().instrument()

    settings = load_settings()
    _configure_logging(settings)

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
