# hugrverse-env

CI environment bootstrapping for hugrverse projects.

This repository builds and releases pre-compiled tooling environments used by
other repositories in the Quantinuum hugrverse. The goal is to provide
libraries that are as compatible as possible across the platforms that matter
most to Rust/Python build pipelines. On Linux, libraries are built inside
[manylinux 2.28](https://github.com/pypa/manylinux) containers, giving broad
binary compatibility across a wide range of distributions. On macOS the
deployment target is set to 11.0.

Each release attaches a compressed archive (`hugrenv-<dep>-<platform>.tar.gz`)
for every supported dependency/platform combination, plus a `hugrenv.lock` file
that records the release version and the Nix-style SHA-256 hash of every
archive.

## What is built

| Component | Version | Description |
|-----------|---------|-------------|
| LLVM      | 21.1.8  | Clang + LLD + LLVM core libraries |
| tket      | 2.16.0  | Quantinuum tket quantum compiler + C API |

## Supported platforms

| Platform tag              | Runner                                                          | Notes |
|---------------------------|-----------------------------------------------------------------|-------|
| `manylinux_2_28_x86_64`   | Docker `quay.io/pypa/manylinux_2_28_x86_64` on `ubuntu-latest` | manylinux 2.28 — broad Linux compatibility |
| `manylinux_2_28_aarch64`  | Docker `quay.io/pypa/manylinux_2_28_aarch64` on `ubuntu-24.04-arm` | manylinux 2.28 — broad Linux compatibility |
| `macosx_11_0_aarch64`     | `macos-14`                                                      | `MACOSX_DEPLOYMENT_TARGET=11.0` |
| `macosx_11_0_x86_64`      | `macos-15-intel`                                                | `MACOSX_DEPLOYMENT_TARGET=11.0` |
| `win_amd64`               | `windows-latest` + MSVC                                         | |

## Using hugrverse-env in your repository

### 1. Obtain a `hugrenv.lock` file

Every [GitHub release](https://github.com/Quantinuum/hugrverse-env/releases)
attaches a `hugrenv.lock` file alongside the compiled archives. Download the
lock file for the version you want to pin and **commit it to your repository**
(e.g. at the repository root as `hugrenv.lock`). The lock file records the
release version and a content hash for every archive so downstream workflows
can verify what they download.

### 2. Install hugrenv packages in GitHub Actions

Use the `.github/actions/install-hugrenv` composite action from this
repository. It reads your committed `hugrenv.lock`, detects the current runner
platform, downloads the requested packages from the matching release, extracts
them, and sets the relevant environment variables (`LLVM_SYS_211_PREFIX`,
`LIBCLANG_PATH`, `TKET_C_API_PATH`, `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH`,
`PATH`, etc.) for subsequent steps.

```yaml
- name: Install hugrenv
  uses: Quantinuum/hugrverse-env/.github/actions/install-hugrenv@main
  with:
    packages: llvm,tket   # comma-separated; defaults to "llvm,tket"
    lockfile: hugrenv.lock  # relative path to your lock file; default is "hugrenv.lock"
```

The action supports all five platforms listed above and works on Linux, macOS,
and Windows runners without any additional setup.

## Repository layout

```
deps/
  llvm/
    manylinux_2_28_x86_64.sh   # Builds LLVM for each platform
    manylinux_2_28_aarch64.sh
    macosx_11_0_aarch64.sh
    macosx_11_0_x86_64.sh
    win_amd64.sh
  tket/
    manylinux_2_28_x86_64.sh   # Builds tket + C API for each platform
    manylinux_2_28_aarch64.sh
    macosx_11_0_aarch64.sh
    macosx_11_0_x86_64.sh
    win_amd64.sh
docker/
  manylinux_2_28_x86_64.Dockerfile   # Local-testing image for x86_64 Linux
  manylinux_2_28_aarch64.Dockerfile  # Local-testing image for AArch64 Linux
.github/
  actions/
    install-hugrenv/
      action.yml    # Composite action: reads lock file, downloads & installs packages
  workflows/
    build.yml       # Builds changed targets on PRs; uploads artifacts
    merge.yml       # Promotes merged-PR artifacts to main-* on merge to main
    release.yml     # Bundles main-* artifacts, generates hugrenv.lock, publishes release
```

## How CI works

1. **Build** (`build.yml`) — triggered on pull requests and manually via
   `workflow_dispatch`.
   * On a PR, only scripts that changed since the base commit are built.
   * Linux targets are built inside the official `quay.io/pypa/manylinux_2_28_*`
     Docker images to ensure manylinux binary compatibility.
   * macOS targets run natively; `MACOSX_DEPLOYMENT_TARGET` is set to `11.0`.
   * The Windows target uses the MSVC toolchain via `ilammy/msvc-dev-cmd`.
   * Each built archive is uploaded as a PR artifact named
     `pr-<head-sha>-<dep>-<platform>`.

2. **Merge** (`merge.yml`) — triggered when a PR is merged to `main`.
   * Finds the PR build artifacts by head SHA and re-uploads them as
     `main-<dep>-<platform>` artifacts (retained 90 days).

3. **Release** (`release.yml`) — triggered manually via `workflow_dispatch`.
   * Downloads all `main-*` promoted artifacts.
   * Generates a `hugrenv.lock` containing the version and Nix-style SHA-256
     hashes for every archive.
   * Creates a GitHub release tagged `v<version>` and attaches all archives
     plus the lock file.

## Adding a new dependency

1. Create `deps/<dependency>/` and add a `<platform>.sh` script for each
   supported platform. Each script accepts an output tarball path as its first
   argument and produces a `hugrenv-<dependency>-<platform>.tar.gz`.
2. Repeat for every platform that should include the dependency.
3. Update this README to document the new component.

## Local development

See [DEVELOPMENT.md](DEVELOPMENT.md) for instructions on testing build-script
changes locally using Docker (Linux) or running scripts natively (macOS/Windows).
