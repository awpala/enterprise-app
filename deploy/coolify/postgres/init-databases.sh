#!/usr/bin/env bash
# Initializes separate application and identity databases on an empty volume.
# The official PostgreSQL entrypoint invokes this only during initial setup.
set -euo pipefail

: "${APP_DB_PASSWORD:?APP_DB_PASSWORD is required.}"
: "${KEYCLOAK_DB_PASSWORD:?KEYCLOAK_DB_PASSWORD is required.}"

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set ON_ERROR_STOP=1 \
  --set app_password="$APP_DB_PASSWORD" \
  --set identity_password="$KEYCLOAK_DB_PASSWORD" <<'SQL'
CREATE ROLE ea_app LOGIN PASSWORD :'app_password';
CREATE DATABASE ea_app OWNER ea_app;
REVOKE ALL ON DATABASE ea_app FROM PUBLIC;
CREATE ROLE ea_keycloak LOGIN PASSWORD :'identity_password';
CREATE DATABASE ea_keycloak OWNER ea_keycloak;
REVOKE ALL ON DATABASE ea_keycloak FROM PUBLIC;
SQL
