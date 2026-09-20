FROM dpage/pgadmin4:9.18 AS bootstrap
COPY servers.json /tmp/servers.json

FROM dpage/pgadmin4:9.18 AS runtime
COPY --from=bootstrap --chown=5050:0 /tmp/servers.json /pgadmin4/servers.json
USER 5050
