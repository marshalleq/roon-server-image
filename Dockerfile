FROM debian:13-slim

LABEL org.opencontainers.image.title="roon-server-image" \
      org.opencontainers.image.description="Debian base for running Roon Server in a container. Roon itself is downloaded on first run." \
      org.opencontainers.image.source="https://github.com/marshalleq/roon-server-image" \
      org.opencontainers.image.licenses="MIT"

# Debian 12 specific: libicu72. Moving to a newer Debian means changing this package name too.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends \
        alsa-utils \
        bash \
        bzip2 \
        ca-certificates \
        cifs-utils \
        curl \
        ffmpeg \
        libicu72 \
    && rm -rf /var/lib/apt/lists/*

ENV ROON_SERVER_PKG=RoonServer_linuxx64.tar.bz2 \
    ROON_SERVER_URL=https://download.roonlabs.net/builds/RoonServer_linuxx64.tar.bz2 \
    ROON_DATAROOT=/data \
    ROON_ID_DIR=/data

VOLUME ["/app", "/data", "/music", "/backup"]

COPY run.sh /run.sh
ENTRYPOINT ["/run.sh"]
