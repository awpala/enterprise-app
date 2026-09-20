#!/usr/bin/env python3
"""Check the Coolify demo, including one real guest model run (writes demo data)."""

import argparse
import base64
import hashlib
import json
import secrets
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def request(url: str, *, method: str = "GET", headers: dict | None = None) -> bytes:
    """Fetch one endpoint with normal TLS verification and a bounded timeout."""
    with urlopen(Request(url, method=method, headers=headers or {}), timeout=20) as response:
        return response.read()


def main() -> None:
    """Verify routing, imported OIDC login, operator UI reachability, and processing."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-url", default="https://ent-app.portfolio-projects.dev")
    parser.add_argument("--api-url", help="Defaults to the application origin.")
    parser.add_argument("--auth-url", default="https://ent-app-auth.portfolio-projects.dev")
    parser.add_argument("--mq-url", default="https://ent-app-mq.portfolio-projects.dev")
    parser.add_argument("--db-url", default="https://ent-app-db.portfolio-projects.dev")
    parser.add_argument("--skip-bearer-check", action="store_true",
                        help="CI only: public HTTPS discovery is not routed to the local stack.")
    args = parser.parse_args()
    app = args.app_url.rstrip("/")
    api = (args.api_url or app).rstrip("/")
    auth = args.auth_url.rstrip("/") + "/realms/enterprise-app"
    request(app + "/api/health")
    request(api + "/health/ready")
    config = json.loads(request(app + "/api/runtime-config"))
    assert config["deploymentTarget"] == "coolify", "Wrong runtime target"
    assert config["enableGuestAuth"] and not config["enableDevAuth"], "Wrong guest/dev policy"
    assert config["auth"]["provider"] == "oidc", "Wrong authentication adapter"
    assert config["auth"]["clientId"] == "ea-ui", "Wrong browser client"
    assert config["auth"]["apiScope"] == "access_as_user", "Wrong API scope"
    discovery = json.loads(request(auth + "/.well-known/openid-configuration"))
    assert discovery["issuer"] == config["auth"]["authority"], "Issuer mismatch"
    assert "S256" in discovery["code_challenge_methods_supported"], "PKCE unavailable"
    challenge = base64.urlsafe_b64encode(hashlib.sha256(secrets.token_bytes(32)).digest()).decode().rstrip("=")
    login_query = urlencode({
        "client_id": "ea-ui", "response_type": "code",
        "redirect_uri": config["apiUrl"] + "/auth/callback",
        "scope": "openid profile email access_as_user", "state": secrets.token_hex(16),
        "code_challenge": challenge, "code_challenge_method": "S256",
    })
    login = request(auth + "/protocol/openid-connect/auth?" + login_query).decode()
    assert "social-google" in login and "social-microsoft" in login, "Provider login buttons missing"
    request(args.mq_url.rstrip("/"))
    assert request(args.db_url.rstrip("/") + "/misc/ping") == b"PING", "pgAdmin unavailable"
    print("UI/API health, runtime configuration, Keycloak login, and administrative endpoints passed.")

    if not args.skip_bearer_check:
        try:
            request(api + "/api/v1/models", headers={"Authorization": "Bearer invalid-demo-token"})
        except HTTPError as error:
            assert error.code == 401, f"Invalid bearer returned {error.code}, expected 401"
        else:
            raise AssertionError("Invalid bearer token was accepted")
        print("Invalid bearer is rejected despite guest access.")

    models = json.loads(request(api + "/api/v1/models?pageSize=100"))["items"]
    model = next((item for item in models if item["status"] != "Archived"), None)
    assert model, "No seeded model is available"
    runs = api + "/api/v1/models/" + model["id"] + "/runs"
    run = json.loads(request(runs, method="POST"))
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        result = json.loads(request(runs + "/" + run["id"]))
        if result["status"] == "Completed":
            assert result["metrics"], "Completed run has no computed metrics"
            print("Guest model run completed with computed metrics.")
            return
        if result["status"] == "Failed":
            raise AssertionError("Guest model run failed; inspect API and worker logs")
        time.sleep(2)
    raise TimeoutError("Guest model run did not complete within 120 seconds")


if __name__ == "__main__":
    main()
