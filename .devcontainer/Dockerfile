ARG NODE_VERSION=22.19.0
ARG QEMU_VNC_REPOSITORY=https://github.com/bcrew1375/QEMU-VNC-Extension.git
ARG QEMU_VNC_REF=v0.2.5

FROM node:${NODE_VERSION}-bookworm-slim AS qemu-vnc-builder

ARG QEMU_VNC_REPOSITORY
ARG QEMU_VNC_REF

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      git && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 --branch "${QEMU_VNC_REF}" \
      "${QEMU_VNC_REPOSITORY}" /build/qemu-vnc && \
    npm ci --prefix /build/qemu-vnc && \
    npm run package --prefix /build/qemu-vnc

FROM ubuntu:noble

# Avoid prompts during package install
ENV DEBIAN_FRONTEND=noninteractive

ARG ZIG_VERSION=0.15.2
ARG LIMINE_BRANCH=v9.x-binary

COPY --from=qemu-vnc-builder \
    /build/qemu-vnc/qemu-vnc.vsix /opt/qemu-vnc/qemu-vnc.vsix

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    ca-certificates \
    build-essential \
    xorriso \
    mtools \
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

# Install Limine as a devcontainer-provided bootloader toolchain dependency.
# The binary branch provides the BIOS/UEFI boot files used by build.zig to
# create bootable x86_64 ISO images, but only ships a Windows limine.exe.
# Build the native Linux limine binary from the bundled source before
# exposing it on PATH.
RUN git clone --depth=1 --branch "${LIMINE_BRANCH}" \
      https://github.com/limine-bootloader/limine.git /opt/limine && \
    make -C /opt/limine && \
    ln -s /opt/limine/limine /usr/local/bin/limine

RUN curl -fsSL \
      "https://raw.githubusercontent.com/ziglang/zig/master/tools/lldb_pretty_printers.py" \
      -o /opt/zig/lldb_pretty_printers.py
