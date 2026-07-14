ARG BUILDER_REF="docker.io/library/debian:bookworm-slim@sha256:9b67294679b30e5d6ab257b40594feeb4a4b81f7fcf4131f4decf0d6a212a9b0"
ARG BASE_REF="ghcr.io/runlix/distroless-runtime-v2-canary:stable@sha256:dbb2f5ac1cf480fca2dd08750c87771b6c2ef097fc248196fe72fbd13c82a3c2"
ARG PACKAGE_URL="https://github.com/sabnzbd/sabnzbd/releases/download/4.5.5/SABnzbd-4.5.5-src.tar.gz"
ARG PAR2TURBO_VERSION=1.3.0
ARG UNRAR_VERSION=7.2.3

FROM ${BUILDER_REF} AS fetch

ARG PACKAGE_URL

WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/sabnzbd \
 && curl -L -f "${PACKAGE_URL}" -o sabnzbd.tar.gz \
 && tar -xzf sabnzbd.tar.gz -C /app/sabnzbd --strip-components=1 \
 && chmod -R u=rwX,go=rX /app/sabnzbd \
 && rm sabnzbd.tar.gz

FROM ${BUILDER_REF} AS sabnzbd-deps

ARG PAR2TURBO_VERSION
ARG UNRAR_VERSION

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-minimal \
    python3-pip \
    python3-dev \
    build-essential \
    autoconf \
    automake \
    libtool \
    curl \
    tar \
    gcc \
    g++ \
    make \
    libffi-dev \
    libssl-dev \
    cargo \
    rustc \
    p7zip-full \
    util-linux \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN curl -fsSL "https://github.com/animetosho/par2cmdline-turbo/archive/refs/tags/v${PAR2TURBO_VERSION}.tar.gz" | tar xzf - -C /tmp --strip-components=1 \
 && aclocal \
 && automake --add-missing \
 && autoconf \
 && ./configure \
 && make \
 && make install

WORKDIR /tmp
RUN curl -fsSL "https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz" -o unrar.tar.gz \
 && tar -xzf unrar.tar.gz \
 && cd unrar \
 && make -f makefile \
 && cp unrar /usr/local/bin/unrar \
 && chmod +x /usr/local/bin/unrar \
 && cd /tmp \
 && rm -rf unrar unrar.tar.gz

COPY --from=fetch /app/sabnzbd/requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

FROM ${BASE_REF}

ARG LIB_DIR=aarch64-linux-gnu

COPY --from=fetch /app/sabnzbd /app/sabnzbd
COPY --from=sabnzbd-deps /usr/local/bin/par2* /usr/local/bin/
COPY --from=sabnzbd-deps /usr/local/bin/unrar /usr/local/bin/unrar
COPY --from=sabnzbd-deps /usr/bin/7za /usr/bin/7za
COPY --from=sabnzbd-deps /usr/bin/nice /usr/bin/nice
COPY --from=sabnzbd-deps /usr/bin/ionice /usr/bin/ionice
COPY --from=sabnzbd-deps /usr/bin/python3 /usr/bin/python3
COPY --from=sabnzbd-deps /usr/bin/python3.11 /usr/bin/python3.11
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libpython3.11.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/local/lib/python3.11/dist-packages /usr/local/lib/python3.11/dist-packages
COPY --from=sabnzbd-deps /usr/lib/python3.11 /usr/lib/python3.11
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libexpat.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libbz2.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/liblzma.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libz.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libreadline.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libncurses.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libtinfo.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libsqlite3.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libgdbm.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libgdbm_compat.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libstdc++.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libgcc_s.so.* /usr/lib/${LIB_DIR}/

WORKDIR /app/sabnzbd
USER 65532:65532
ENTRYPOINT ["/usr/bin/python3", "-OO", "SABnzbd.py", "--browser", "0", "--server", "0.0.0.0:8080", "--config-file", "/config"]
