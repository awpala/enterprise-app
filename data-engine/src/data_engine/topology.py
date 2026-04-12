"""RabbitMQ topology constants for the data engine.

These names MUST stay in sync with the .NET ``EA.Contracts.Messages`` namespace.
MassTransit derives exchange names directly from the CLR type — any drift here
will cause messages to be published to or consumed from the wrong exchange.

Exchange naming convention: ``{Namespace}:{TypeName}``
Queue naming convention:    ``{service}.{message-type-kebab}``
Message-type URN convention: ``urn:message:{Namespace}:{TypeName}``
"""

# ---------------------------------------------------------------------------
# Exchange names — MassTransit fanout exchanges, one per message type.
# ---------------------------------------------------------------------------

EXCHANGE_MODEL_RUN_REQUESTED: str = "EA.Contracts.Messages:ModelRunRequested"
EXCHANGE_MODEL_RUN_STARTED: str = "EA.Contracts.Messages:ModelRunStarted"
EXCHANGE_MODEL_RUN_COMPLETED: str = "EA.Contracts.Messages:ModelRunCompleted"
EXCHANGE_MODEL_RUN_FAILED: str = "EA.Contracts.Messages:ModelRunFailed"

# ---------------------------------------------------------------------------
# Message-type URNs — placed in the MassTransit envelope ``messageType`` array.
# ---------------------------------------------------------------------------

URN_MODEL_RUN_REQUESTED: str = "urn:message:EA.Contracts.Messages:ModelRunRequested"
URN_MODEL_RUN_STARTED: str = "urn:message:EA.Contracts.Messages:ModelRunStarted"
URN_MODEL_RUN_COMPLETED: str = "urn:message:EA.Contracts.Messages:ModelRunCompleted"
URN_MODEL_RUN_FAILED: str = "urn:message:EA.Contracts.Messages:ModelRunFailed"

# ---------------------------------------------------------------------------
# Queue names — durable queues, one per consumer service / message type.
# ---------------------------------------------------------------------------

QUEUE_DATA_ENGINE_MODEL_RUN_REQUESTED: str = "ea.data-engine.model-run-requested"
QUEUE_API_MODEL_RUN_STARTED: str = "ea.api.model-run-started"
QUEUE_API_MODEL_RUN_COMPLETED: str = "ea.api.model-run-completed"
QUEUE_API_MODEL_RUN_FAILED: str = "ea.api.model-run-failed"
