# Doory all-in-one image for Railway: API (gunicorn :8000) + realtime (uvicorn :8001) + nginx web (:$PORT)
# in one container, so the media volume is shared the way docker-compose shares it between api/realtime/web.
ARG DOORY_VERSION=0.2.0
FROM ghcr.io/shaongitbd/doory-frontend:${DOORY_VERSION} AS web
FROM ghcr.io/shaongitbd/doory-backend:${DOORY_VERSION}
USER root
RUN apt-get update && apt-get install -y --no-install-recommends nginx tini \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default
COPY --from=web /usr/share/nginx/html /usr/share/nginx/html
COPY --from=web /etc/nginx/snippets/security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY --from=web /etc/nginx/templates/default.conf.template /tmp/doory.conf
RUN sed -i \
      -e '/^resolver /d' \
      -e 's/server doory-api:8000 resolve;/server 127.0.0.1:8000;/' \
      -e 's/server doory-realtime:8001 resolve;/server 127.0.0.1:8001;/' \
      -e 's/server doory-mcp:8002 resolve;/server 127.0.0.1:8002;/' \
      -e 's#/srv/media#/app/media#g' \
      -e 's/listen 8080 default_server;/listen 8080 default_server;\n    listen [::]:8080 default_server;/' \
      -e 's#^set_real_ip_from 127.0.0.1;#set_real_ip_from 127.0.0.1;\nset_real_ip_from 100.64.0.0/10;#' \
      /tmp/doory.conf \
    && mv /tmp/doory.conf /etc/nginx/conf.d/doory.conf \
    && grep -q "127.0.0.1:8000" /etc/nginx/conf.d/doory.conf && ! grep -q "doory-api" /etc/nginx/conf.d/doory.conf \
    && nginx -t
COPY railway/start-all.sh /usr/local/bin/start-all.sh
RUN chmod 755 /usr/local/bin/start-all.sh
EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-all.sh"]
