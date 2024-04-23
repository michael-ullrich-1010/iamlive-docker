ARG ALPINE_VERSION=3.18
ARG IAMLIVE_VERSION=v0.53.0


# Base image
FROM alpine:${ALPINE_VERSION} AS base
RUN apk --update upgrade && \
    apk add --update ca-certificates bash jq=~1.6 && \
    update-ca-certificates


# Download iamlive binary from GitHub
FROM base as download
ARG IAMLIVE_VERSION
WORKDIR /downloads/
RUN \
    wget -O iamlive.tar.gz "https://github.com/iann0036/iamlive/releases/download/${IAMLIVE_VERSION}/iamlive-${IAMLIVE_VERSION}-linux-amd64.tar.gz" && \
    tar -xzf iamlive.tar.gz


# App
FROM base AS app
WORKDIR /app/
COPY --from=download "/downloads/iamlive" ./
RUN addgroup -S "appgroup" && adduser -S "appuser" -G "appgroup" && \
    chown -R "appuser:appgroup" .
# Create entrypoint.sh directly inside the image
RUN echo '#!/usr/bin/env bash' > /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo 'set -e' >> /app/entrypoint.sh && \
    echo 'set -o pipefail' >> /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo '_FORMAT_LOGS="${FORMAT_LOGS:-"true"}"' >> /app/entrypoint.sh && \
    echo '_ALLOWED_ADDRESS="${ALLOWED_ADDRESS:-"0.0.0.0"}"' >> /app/entrypoint.sh && \
    echo '' >> /app/entrypoint.sh && \
    echo 'if [[ "$_FORMAT_LOGS" = "true" ]]; then' >> /app/entrypoint.sh && \
    echo '    /app/iamlive --output-file "/app/iamlive.log" \' >> /app/entrypoint.sh && \
    echo '        --mode proxy --bind-addr "${_ALLOWED_ADDRESS}:10080" $@ | jq -c .' >> /app/entrypoint.sh && \
    echo 'else' >> /app/entrypoint.sh && \
    echo '    /app/iamlive --output-file "/app/iamlive.log" \' >> /app/entrypoint.sh && \
    echo '        --mode proxy --bind-addr "${_ALLOWED_ADDRESS}:10080" $@' >> /app/entrypoint.sh && \
    echo 'fi' >> /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

USER "appuser"
EXPOSE 10080
ENTRYPOINT [ "/app/entrypoint.sh" ]
CMD [ "--force-wildcard-resource" ]
