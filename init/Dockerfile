FROM alpine:3.19

# Install required tools
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    docker-cli \
    docker-cli-compose \
    postgresql-client \
    netcat-openbsd \
    python3 \
    py3-pip

# Copy all config examples and scripts
COPY sentry/config.example.yml /templates/sentry/config.yml
COPY sentry/sentry.conf.example.py /templates/sentry/sentry.conf.py
COPY sentry/entrypoint.sh /templates/sentry/entrypoint.sh
COPY relay/config.example.yml /templates/relay/config.yml
COPY symbolicator/config.example.yml /templates/symbolicator/config.yml
COPY clickhouse/config.xml /templates/clickhouse/config.xml
COPY clickhouse/default-password.xml /templates/clickhouse/default-password.xml
COPY redis.conf /templates/redis.conf
COPY nginx.conf /templates/nginx.conf
COPY geoip /templates/geoip

# Copy initialization script
COPY init/init.sh /init.sh
RUN chmod +x /init.sh

ENTRYPOINT ["/init.sh"]
