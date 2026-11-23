FROM debian:13-slim

LABEL org.opencontainers.image.title="roon-server-image" \
      org.opencontainers.image.description="Debian base for running Roon Server in a container. Roon itself is downloaded on first run." \
      org.opencontainers.image.source="https://github.com/marshalleq/roon-server-image" \
      org.opencontainers.image.licenses="MIT"

# Package list follows Roon's own image (github.com/RoonLabs/roon-docker, also Debian 13), except that
# ffmpeg comes from Debian, so it gets security updates with every weekly rebuild.
#   libicu76       .NET globalisation (Debian 13 specific: a different Debian release needs a different package)
#   libasound2t64  ALSA audio, needed by one of Roon's own libraries
#   libfreetype6   needed by a font library Roon bundles
#   procps         provides ps, which Roon's self-update script uses
#   ffmpeg         Roon Server will not start without ffmpeg on the PATH
#   cifs-utils     mounting network shares from inside Roon
# The setuid bit on mount.cifs is removed: Roon runs as a normal user here and does not need it.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends \
        bash \
        bzip2 \
        ca-certificates \
        cifs-utils \
        curl \
        ffmpeg \
        libasound2t64 \
        libfreetype6 \
        libicu76 \
        procps \
        tzdata \
    && chmod u-s /usr/sbin/mount.cifs \
    && rm -rf /var/lib/apt/lists/*

ENV ROON_SERVER_PKG=RoonServer_linuxx64.tar.bz2 \
    ROON_SERVER_URL=https://download.roonlabs.net/builds/RoonServer_linuxx64.tar.bz2 \
    ROON_DATAROOT=/data \
    ROON_ID_DIR=/data

VOLUME ["/app", "/data", "/music", "/backup"]

COPY run.sh /run.sh
ENTRYPOINT ["/run.sh"]
