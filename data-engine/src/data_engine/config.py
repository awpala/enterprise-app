"""Configuration loaded from environment variables via pydantic-settings."""

from pydantic_settings import BaseSettings


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

    # Reconnect behaviour.
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
    return Settings()
