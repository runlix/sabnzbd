# Builder tag from VERSION.json builder.tag (e.g., "bookworm-slim")
ARG BUILDER_TAG=bookworm-slim
# Base tag (variant-arch) from VERSION.json base.tag (e.g., "release-2025.12.29.1-linux-arm64-latest")
ARG BASE_TAG=release-2025.12.29.1-linux-arm64-latest
# Selected digests (build script will set based on target configuration)
# Default to empty string - build script will always provide valid digests
# If empty, FROM will fail (which is desired to enforce digest pinning)
ARG BUILDER_DIGEST=""
ARG BASE_DIGEST=""
# Package URL from VERSION.json package_url
ARG PACKAGE_URL=""
# par2turbo version (can be added to VERSION.json later if needed)
ARG PAR2TURBO_VERSION=1.3.0

# STAGE 1 — fetch SABnzbd source
# Build script will pass BUILDER_TAG and BUILDER_DIGEST from VERSION.json
# Format: debian:bookworm-slim@sha256:digest (when digest provided)
FROM docker.io/library/debian:${BUILDER_TAG}@${BUILDER_DIGEST} AS fetch

# Redeclare ARG in this stage so it's available for use in RUN commands
ARG PACKAGE_URL

WORKDIR /app

# Use BuildKit cache mounts to persist apt cache between builds
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
 && rm sabnzbd.tar.gz

# STAGE 2 — build par2turbo and install Python dependencies
# Build script will pass BUILDER_TAG and BUILDER_DIGEST from VERSION.json
FROM docker.io/library/debian:${BUILDER_TAG}@${BUILDER_DIGEST} AS sabnzbd-deps

ARG PAR2TURBO_VERSION

# Use BuildKit cache mounts to persist apt cache between builds
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
 && rm -rf /var/lib/apt/lists/*

# Build par2turbo
WORKDIR /tmp
RUN curl -fsSL "https://github.com/animetosho/par2cmdline-turbo/archive/refs/tags/v${PAR2TURBO_VERSION}.tar.gz" | tar xzf - -C /tmp --strip-components=1 \
 && aclocal \
 && automake --add-missing \
 && autoconf \
 && ./configure \
 && make \
 && make install

# Install Python packages from SABnzbd requirements.txt
# Copy requirements.txt from fetch stage
COPY --from=fetch /app/sabnzbd/requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

# STAGE 3 — distroless final image
# Build script will pass BASE_TAG (from VERSION.json base.tag) and BASE_DIGEST
# Format: ghcr.io/runlix/distroless-runtime:release-2025.12.29.1-linux-arm64-latest@sha256:digest (when digest provided)
FROM ghcr.io/runlix/distroless-runtime:${BASE_TAG}@${BASE_DIGEST}

# Hardcoded for arm64 - no conditionals needed!
ARG LIB_DIR=aarch64-linux-gnu
ARG LD_SO=ld-linux-aarch64.so.1

# Copy SABnzbd source
COPY --from=fetch /app/sabnzbd /app/sabnzbd

# Copy par2 binaries
COPY --from=sabnzbd-deps /usr/local/bin/par2* /usr/local/bin/

# Copy Python runtime
COPY --from=sabnzbd-deps /usr/bin/python3 /usr/bin/python3
COPY --from=sabnzbd-deps /usr/bin/python3.11 /usr/bin/python3.11

# Copy Python shared libraries
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libpython3.11.so.* /usr/lib/${LIB_DIR}/

# Copy Python site-packages (installed packages)
# Debian bookworm uses Python 3.11
COPY --from=sabnzbd-deps /usr/local/lib/python3.11/dist-packages /usr/local/lib/python3.11/dist-packages

# Copy Python standard library
COPY --from=sabnzbd-deps /usr/lib/python3.11 /usr/lib/python3.11

WORKDIR /app/sabnzbd
USER 65532:65532
ENTRYPOINT ["/usr/bin/python3", "-OO", "SABnzbd.py", "--browser", "0", "--server", "0.0.0.0:8080", "--config-file", "/config"]

