#!/usr/bin/env python3
"""Create the ignored Coolify environment file without printing credentials."""

import os
from pathlib import Path
import secrets


def main() -> None:
    """Create credentials once; preserve any existing configuration unchanged."""
    directory = Path(__file__).resolve().parent
    destination = directory / ".env"
    template = (directory / ".env.example").read_text()
    for key in (
        "POSTGRES_PASSWORD",
        "APP_DB_PASSWORD",
        "KEYCLOAK_DB_PASSWORD",
        "RABBITMQ_PASSWORD",
        "KEYCLOAK_ADMIN_PASSWORD",
        "PGADMIN_PASSWORD",
    ):
        template = template.replace(f"{key}=\n", f"{key}={secrets.token_hex(32)}\n")
    try:
        descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        print("Existing deploy/coolify/.env preserved; no credentials changed.")
        return
    with os.fdopen(descriptor, "w") as output:
        output.write(template)
    print("Created ignored deploy/coolify/.env with local service credentials.")
    print("Enter the four Google/Microsoft fields there; do not paste them into chat.")


if __name__ == "__main__":
    main()
