FROM ubuntu:noble

# Avoid prompts during package install
ENV DEBIAN_FRONTEND=noninteractive

ARG ZIG_VERSION=0.15.2

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    ca-certificates \
    build-essential \
    qemu-system \
    qemu-utils \
    qemu-user \
    git && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /tmp/zig-local-cache /tmp/zig-global-cache

# Detect architecture and download correct Zig binary
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) ARCH="x86_64" ;; \
        arm64) ARCH="aarch64" ;; \
        *) echo "Unsupported architecture" && exit 1 ;; \
    esac; \
    curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-${ARCH}-linux-${ZIG_VERSION}.tar.xz" -o zig.tar.xz; \
    tar -xf zig.tar.xz; \
    mv zig-${ARCH}-* /opt/zig; \
    ln -s /opt/zig/zig /usr/local/bin/zig; \
    rm zig.tar.xz

RUN curl -fsSL \
      "https://raw.githubusercontent.com/ziglang/zig/master/tools/lldb_pretty_printers.py" \
      -o /opt/zig/lldb_pretty_printers.py

ENV ZIG_GLOBAL_CACHE_DIR=/tmp/zig-global-cache
ENV ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache
