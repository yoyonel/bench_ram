# bench_ram — Multi-toolchain benchmark image
# Base: debian:bookworm-slim (glibc) — see docs/containerization.md for rationale
#
# Provides all 15 language toolchains needed by bench_ram.
# Usage:
#   docker build -t bench_ram .
#   docker run --rm -v "$PWD:/bench:ro" -v "$PWD/results:/bench/results" bench_ram ./bench_ram.sh

FROM debian:bookworm-slim

# Pinned versions for reproducibility
ARG GO_VERSION=1.22.5
ARG RUST_VERSION=1.79.0
ARG ZIG_VERSION=0.13.0
ARG NIM_VERSION=2.0.8
ARG VLANG_VERSION=0.5.1
ARG BUN_VERSION=1.1.18
ARG NODE_MAJOR=20

# ── Stage: apt packages ─────────────────────────────────────
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y --no-install-recommends \
        # Build essentials
        ca-certificates curl unzip xz-utils \
        # C / C++
        gcc g++ libc6-dev \
        # Python
        python3 \
        # Ruby
        ruby \
        # Perl
        perl \
        # PHP
        php-cli \
        # Lua
        lua5.4 \
        # Java (JDK for javac + java)
        default-jdk-headless \
        # Node.js (from Debian repos — stable enough for our use)
        nodejs \
    && ln -sf /usr/bin/lua5.4 /usr/bin/lua

# ── Stage: Go ────────────────────────────────────────────────
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# ── Stage: Rust (minimal, no cargo needed — only rustc) ──────
RUN curl -fsSL "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /tmp && \
    /tmp/rust-${RUST_VERSION}-x86_64-unknown-linux-gnu/install.sh \
        --prefix=/usr/local --components=rustc,rust-std-x86_64-unknown-linux-gnu && \
    rm -rf /tmp/rust-*

# ── Stage: Zig ───────────────────────────────────────────────
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /usr/local && \
    ln -s /usr/local/zig-linux-x86_64-${ZIG_VERSION}/zig /usr/local/bin/zig

# ── Stage: Nim ───────────────────────────────────────────────
RUN curl -fsSL "https://nim-lang.org/download/nim-${NIM_VERSION}-linux_x64.tar.xz" \
    | tar -xJ -C /usr/local && \
    ln -s /usr/local/nim-${NIM_VERSION}/bin/nim /usr/local/bin/nim

# ── Stage: V ─────────────────────────────────────────────────
RUN curl -fsSL "https://github.com/vlang/v/releases/download/${VLANG_VERSION}/v_linux.zip" \
    -o /tmp/v.zip && \
    unzip -q /tmp/v.zip -d /usr/local && \
    ln -s /usr/local/v/v /usr/local/bin/v && \
    rm /tmp/v.zip

# ── Stage: Bun ───────────────────────────────────────────────
RUN curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip" \
    -o /tmp/bun.zip && \
    unzip -q /tmp/bun.zip -d /tmp && \
    mv /tmp/bun-linux-x64/bun /usr/local/bin/bun && \
    chmod +x /usr/local/bin/bun && \
    rm -rf /tmp/bun*

# ── Verification ─────────────────────────────────────────────
RUN echo "=== Toolchain verification ===" && \
    gcc --version | head -1 && \
    g++ --version | head -1 && \
    python3 --version && \
    ruby --version && \
    perl --version | grep version && \
    php --version | head -1 && \
    lua -v && \
    java --version 2>&1 | head -1 && \
    node --version && \
    go version && \
    rustc --version && \
    zig version && \
    nim --version 2>&1 | head -1 && \
    v --version && \
    bun --version && \
    echo "=== All 15 toolchains OK ==="

WORKDIR /bench
