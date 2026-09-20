FROM quay.io/keycloak/keycloak:26.7.4 AS build
ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.7.4 AS runtime
COPY --from=build /opt/keycloak/ /opt/keycloak/
COPY --chown=1000:0 enterprise-app-realm.json /opt/keycloak/data/import/enterprise-app-realm.json
COPY --chown=1000:0 --chmod=755 healthcheck.sh /opt/keycloak/bin/ea-healthcheck.sh
USER 1000
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized", "--import-realm"]
