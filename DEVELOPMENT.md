# Development Guide

This guide explains how to test build-script changes locally in the same
sandboxed environment that CI uses.

## Prerequisites

* [Docker](https://docs.docker.com/get-docker/) installed and running.
* For AArch64 images on an x86_64 host: Docker with multi-platform support
  (e.g. [QEMU binfmt](https://github.com/multiarch/qemu-user-static) or
  Docker Desktop's built-in emulation). Building natively is strongly
  recommended for AArch64 because emulation will be very slow for a full
  LLVM or tket build.

## Linux (manylinux) builds

The Dockerfiles in `docker/` wrap the official `quay.io/pypa/manylinux_2_28_*`
images. They do not embed the build scripts; instead the repository root is
mounted at `/host` at runtime so that edits are picked up immediately without
rebuilding the image.

Each build script lives at `deps/<dependency>/<platform>.sh` and takes a single
argument: the path where the output `.tar.gz` should be written.

### x86_64

```bash
# 1. Build the helper image (one-time, or after Dockerfile changes)
docker build \
  -f docker/manylinux_2_28_x86_64.Dockerfile \
  -t hugrverse-env-manylinux-x86_64 \
  .

# 2. Run a single dependency build (e.g. llvm)
mkdir -p artifacts
docker run --rm \
  -v "$(pwd):/host" \
  hugrverse-env-manylinux-x86_64 \
  bash /host/deps/llvm/manylinux_2_28_x86_64.sh \
       /host/artifacts/hugrenv-llvm-manylinux_2_28_x86_64.tar.gz
```

Replace `llvm` with `tket` (or any other dependency) to build that component
instead.

### AArch64 (native AArch64 host recommended)

```bash
docker build \
  -f docker/manylinux_2_28_aarch64.Dockerfile \
  -t hugrverse-env-manylinux-aarch64 \
  .

mkdir -p artifacts
docker run --rm \
  -v "$(pwd):/host" \
  hugrverse-env-manylinux-aarch64 \
  bash /host/deps/llvm/manylinux_2_28_aarch64.sh \
       /host/artifacts/hugrenv-llvm-manylinux_2_28_aarch64.tar.gz
```

> **Tip:** pass `-e VERBOSE=1` to enable verbose output from build sub-steps,
> and `-e MAKEFLAGS="-j4"` to limit parallelism if memory is constrained.

### Iterating quickly

To drop into an interactive shell inside the container without running a full
build:

```bash
docker run --rm -it \
  -v "$(pwd):/host" \
  hugrverse-env-manylinux-x86_64 \
  bash
```

You can then run individual scripts (e.g.
`bash /host/deps/llvm/manylinux_2_28_x86_64.sh /tmp/hugrenv-llvm-manylinux_2_28_x86_64.tar.gz`)
to test in isolation.

## macOS builds

macOS build scripts run natively; no Docker is needed. The `MACOSX_DEPLOYMENT_TARGET`
environment variable should be set to `11.0` to match what CI uses.

```bash
export MACOSX_DEPLOYMENT_TARGET=11.0

# ARM64
bash deps/llvm/macosx_11_0_aarch64.sh /tmp/hugrenv-llvm-macosx_11_0_aarch64.tar.gz

# x86_64 (Intel Mac)
bash deps/llvm/macosx_11_0_x86_64.sh /tmp/hugrenv-llvm-macosx_11_0_x86_64.tar.gz
```

Replace `llvm` with `tket` to build the tket dependency. The scripts will
install any missing dependencies via Homebrew.

## Windows builds

Windows scripts are standard Bash scripts that must be run from a shell that
has the MSVC environment loaded (e.g. Git Bash launched from a **Developer
Command Prompt for VS 2022**, or after sourcing `vcvars64.bat`). CI uses the
`ilammy/msvc-dev-cmd` action to set this up automatically.

```bash
bash deps/llvm/win_amd64.sh /tmp/hugrenv-llvm-win_amd64.tar.gz
bash deps/tket/win_amd64.sh /tmp/hugrenv-tket-win_amd64.tar.gz
```

> The MSVC environment can be loaded in a regular PowerShell session by
> sourcing
> `"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"`.

## Adding a new dependency

1. Create a `deps/<dependency>/` directory with a `<platform>.sh` script for
   each supported platform. Each script must accept the output tarball path as
   its first argument.
2. Test locally using the methods above before opening a PR.
3. Update `README.md` to document the new component.

## Verifying the archive

After a local build, inspect the archive to confirm its contents:

```bash
# Linux / macOS
tar -tzf artifacts/hugrenv-llvm-manylinux_2_28_x86_64.tar.gz | head -20

# Windows
tar -tzf /tmp/hugrenv-llvm-win_amd64.tar.gz | head -20
```

LLVM binaries should appear under `hugrverse/bin/` in the archive; tket
libraries under `hugrverse/lib/`.
