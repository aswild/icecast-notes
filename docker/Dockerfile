# Dockerfile for an Icecast server, built from the latest git HEAD.

# The entrypoint script (from https://github.com/infiniteproject/icecast) can set
# up icecast.xml using the following environment variables:
#   ICECAST_SOURCE_PASSWORD
#   ICECAST_RELAY_PASSWORD
#   ICECAST_ADMIN_PASSWORD
#   ICECAST_ADMIN_USERNAME
#   ICECAST_ADMIN_EMAIL
#   ICECAST_LOCATION
#   ICECAST_HOSTNAME
#   ICECAST_MAX_CLIENTS
#   ICECAST_MAX_SOURCES
# Or you can bind-mount a custom file over /etc/icecast.xml and leave these variables unset

FROM alpine:latest

RUN set -x && \
    addgroup -S icecast && \
    adduser -S -h / -s /sbin/nologin -G icecast icecast && \
    \
    apk add --no-cache \
        libxslt libxml2 libogg libvorbis libtheora openssl curl && \
    apk add --no-cache --virtual .build-deps \
        libxslt-dev libxml2-dev libogg-dev libvorbis-dev libtheora-dev \
        openssl-dev curl-dev zlib-dev \
        git build-base autoconf automake libtool && \
    \
    mkdir -p /usr/src && cd /usr/src && \
    git clone --recursive https://gitlab.xiph.org/xiph/icecast-server.git && \
    cd icecast-server && \
    ./autogen.sh && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j$(nproc) && make install && \
    \
    cd / && \
    rm -rf /usr/src /usr/share/doc/icecast && \
    apk del .build-deps && \
    \
    echo "Done"

COPY entrypoint.sh /entrypoint

EXPOSE 8000
VOLUME ["/var/log/icecast"]
ENTRYPOINT ["/entrypoint"]
CMD ["/usr/bin/icecast", "-c", "/etc/icecast.xml"]
