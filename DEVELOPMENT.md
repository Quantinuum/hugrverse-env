# Development Guide

This guide explains how to test build-script changes locally in the same
sandboxed environment that CI uses.

## Prerequisites

* [Docker](https://docs.docker.com/get-docker/) installed and running.
* For AArch64 images on an x86_64 host: Docker with multi-platform support
  (e.g. [QEMU binfmt](https://github.com/multiarch/qemu-user-static) or
  Docker Desktop's built-in emulation). Building natively is strongly
  recommended for AArch64 because emulation will be very slow for a full
  LLVM build.

## Linux (manylinux) builds

The Dockerfiles in `docker/` wrap the official `quay.io/pypa/manylinux_2_28_*`
images. They do not embed the build scripts; instead the repository root is
mounted at `/host` at runtime so that edits are picked up immediately without
rebuilding the image.

### x86_64

```bash
# 1. Build the helper image (one-time, or after Dockerfile changes)
docker build \
  -f docker/manylinux_2_28_x86_64.Dockerfile \
  -t hugrverse-env-manylinux-x86_64 \
  .

# 2. Run the full build (output lands in ./artifacts/)
mkdir -p artifacts
docker run --rm \
  -v "$(pwd):/host" \
  hugrverse-env-manylinux-x86_64 \
  /host/builds/manylinux_2_28_x86_64/build.sh \
  /host/artifacts/hugrverse_env_manylinux_2_28_x86_64.tar.gz
```

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
  /host/builds/manylinux_2_28_aarch64/build.sh \
  /host/artifacts/hugrverse_env_manylinux_2_28_aarch64.tar.gz
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
  -c 'cd /host && bash'
```

You can then run individual sub-scripts (e.g.
`bash builds/manylinux_2_28_x86_64/llvm/build.sh`) to test in isolation.

## macOS builds

macOS build scripts run natively; no Docker is needed.

```bash
# ARM64
bash builds/macosx_11_0_arm64/build.sh /tmp/hugrverse_env_macosx_11_0_arm64.tar.gz

# x86_64 (Intel Mac)
bash builds/macosx_11_0_x86_64/build.sh /tmp/hugrverse_env_macosx_11_0_x86_64.tar.gz
```

The scripts will install any missing dependencies via Homebrew.

## Windows builds

Open a **Developer PowerShell for VS 2022** (or run `.\builds\win_amd64\build.ps1`
from a terminal that already has the MSVC environment loaded):

```powershell
.\builds\win_amd64\build.ps1 -OutputPath C:\Temp\hugrverse_env_win_amd64.zip
```

> The MSVC environment can be loaded in a regular PowerShell session with the
> `ilammy/msvc-dev-cmd` action logic, or by sourcing
> `"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"`.

## Adding a new component

1. Create `builds/<platform>/<component>/build.sh` (or `.ps1`).
2. Source it from the platform's parent `build.sh` / `build.ps1`.
3. Test locally using the methods above before opening a PR.
4. Update `README.md` to document the new component.

## Verifying the archive

After a local build, inspect the archive to confirm its contents:

```bash
# Linux / macOS
tar -tzf artifacts/hugrverse_env_manylinux_2_28_x86_64.tar.gz | head -20

# Windows
unzip -l artifacts\hugrverse_env_win_amd64.zip | head -20
```

Installed LLVM binaries should appear under `opt/llvm/bin/` in the archive.
