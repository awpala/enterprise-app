FROM postgres:16 AS bootstrap
COPY init-databases.sh /bootstrap/init-databases.sh

FROM postgres:16 AS runtime
COPY --from=bootstrap --chmod=755 /bootstrap/init-databases.sh /docker-entrypoint-initdb.d/init-databases.sh
USER postgres
