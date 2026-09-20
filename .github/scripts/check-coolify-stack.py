#!/usr/bin/env python3
"""Build and smoke-test the disposable production stack on a Docker-capable CI host."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> None:
    """Use synthetic credentials and loopback ports; never load the operator .env."""
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="ea-coolify-ci-") as temporary:
        directory = Path(temporary)
        manifest = directory / "compose.yaml"
        # Coolify consumes this property before invoking Compose. Use a standard
        # extension key in standalone CI so Docker can validate the same manifest.
        source = (root / "compose.prod.yaml").read_text()
        manifest.write_text(source.replace("    exclude_from_hc:", "    x-exclude_from_hc:"))
        environment = directory / "ci.env"
        lines = []
        values = {}
        for line in (root / "deploy/coolify/.env.example").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            values[key] = value or hashlib.sha256(("ci-only-" + key).encode()).hexdigest()
            lines.append(f"{key}={values[key]}")
        environment.write_text("\n".join(lines) + "\n")
        overrides = directory / "ports.json"
        overrides.write_text(json.dumps({"services": {
            "ea-ui": {"ports": ["127.0.0.1:13000:3000"]},
            "ea-api": {"ports": ["127.0.0.1:18000:8000"]},
            "ea-keycloak": {"ports": ["127.0.0.1:18080:8080"]},
            "ea-rabbitmq": {"ports": ["127.0.0.1:15672:15672"]},
            "ea-pgadmin": {"ports": ["127.0.0.1:18081:8080"]},
        }}))
        # Explicit variables override any unrelated runner environment without
        # sourcing a shell file. Sequential builds fit the hosted runner memory.
        process_env = {**os.environ, **values, "COMPOSE_PARALLEL_LIMIT": "1"}
        command = ["docker", "compose", "--project-directory", str(root),
                   "--project-name", "ea-coolify-ci", "--env-file", str(environment),
                   "--file", str(manifest), "--file", str(overrides)]

        def compose(*arguments: str, check: bool = True) -> None:
            subprocess.run(command + list(arguments), cwd=root, env=process_env, check=check)

        compose("config", "--quiet")
        try:
            compose("build")
            compose("up", "--detach", "--wait", "--wait-timeout", "240")
            subprocess.run([
                sys.executable, str(root / "deploy/coolify/smoke.py"),
                "--app-url", "http://127.0.0.1:13000", "--api-url", "http://127.0.0.1:18000",
                "--auth-url", "http://127.0.0.1:18080", "--mq-url", "http://127.0.0.1:15672",
                "--db-url", "http://127.0.0.1:18081", "--skip-bearer-check",
            ], cwd=root, check=True)
            # Exercise idempotent migration application against the existing DB.
            compose("run", "--rm", "--no-deps", "ea-migrations")
        except subprocess.CalledProcessError:
            compose("ps", "--all", check=False)
            compose("logs", "--no-color", "--tail", "100", check=False)
            raise
        finally:
            compose("down", "--volumes", "--remove-orphans", check=False)


if __name__ == "__main__":
    main()
