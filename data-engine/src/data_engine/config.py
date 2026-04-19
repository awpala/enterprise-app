"""Configuration loaded from environment variables via pydantic-settings."""

import logging

from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    """Application settings populated from environment variables.

    All values have sensible defaults for local development.
    """

    rabbitmq_host: str = "ea-rabbitmq"
    rabbitmq_port: int = 5672
    rabbitmq_user: str = "guest"
    rabbitmq_password: str = "guest"
    rabbitmq_vhost: str = "/"

    log_level: str = "INFO"

    # Reconnect behavior.
    reconnect_delay_initial: float = 1.0
    reconnect_delay_max: float = 60.0
    reconnect_delay_multiplier: float = 2.0

    @property
    def rabbitmq_url(self) -> str:
        """Build an AMQP URL from individual components."""
        return (
            f"amqp://{self.rabbitmq_user}:{self.rabbitmq_password}"
            f"@{self.rabbitmq_host}:{self.rabbitmq_port}{self.rabbitmq_vhost}"
        )

    model_config = {"env_prefix": "", "case_sensitive": False}


def load_settings() -> Settings:
    """Create and return a validated ``Settings`` instance."""
    settings = Settings()
    logger.info(
        "Configuration loaded: rabbitmq_host=%s, rabbitmq_port=%d, rabbitmq_vhost=%s, "
        "log_level=%s, reconnect_delay_initial=%.1f, reconnect_delay_max=%.1f, "
        "reconnect_delay_multiplier=%.1f",
        settings.rabbitmq_host,
        settings.rabbitmq_port,
        settings.rabbitmq_vhost,
        settings.log_level,
        settings.reconnect_delay_initial,
        settings.reconnect_delay_max,
        settings.reconnect_delay_multiplier,
    )
    return settings
