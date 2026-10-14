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
| `win_mingw_amd64`         | `windows-latest` + pinned MinGW GCC 14.2.0                       | Separate GNU ABI builds of LLVM and tket, including their MinGW runtime DLLs |
| `emscripten_4_0_9_wasm32` | `ubuntu-latest` + Emscripten SDK 4.0.9                         | WebAssembly target for Pyodide's [`pyemscripten_2025_0`](https://pyodide.org/en/stable/development/abi/313.html) platform. Currently only the `tket` package is built. |
| `emscripten_5_0_3_wasm32` | `ubuntu-latest` + Emscripten SDK 5.0.3                         | WebAssembly target for Pyodide's [`pyemscripten_2026_0`](https://pyodide.org/en/stable/development/abi/314.html) platform (Python 3.14). Currently only the `tket` package is built. |

## Using hugrverse-env in your repository

### 1. Obtain a `hugrenv.lock` file

Every [GitHub release](https://github.com/Quantinuum/hugrverse-env/releases)
attaches a `hugrenv.lock` file alongside the compiled archives. Download the
lock file for the version you want to pin and **commit it to your repository**
(e.g. at the repository root as `hugrenv.lock`). The lock file records the
release version and a content hash for every archive so downstream workflows
can verify what they download.

### 2. Install hugrenv packages in GitHub Actions

Use the `install-hugrenv-action` composite action from this
repository. It reads your committed `hugrenv.lock`, detects the current runner
platform, downloads the requested packages from the matching release, extracts
them, and sets the relevant environment variables (`LLVM_SYS_211_PREFIX`,
`LIBCLANG_PATH`, `TKET_C_API_PATH`, `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH`,
`PATH`, etc.) for subsequent steps.

```yaml
- name: Install hugrenv
  uses: Quantinuum/hugrverse-env/install-hugrenv-action@main
  with:
    packages: llvm,tket   # comma-separated; defaults to "llvm,tket"
    lockfile: hugrenv.lock  # relative path to your lock file; default is "hugrenv.lock"
```

The action supports all platforms listed above and works on Linux, macOS,
and Windows runners without any additional setup.

The platform tag is detected automatically from the runner, but you can override it with the `target` input (e.g. cross-compiling for WebAssembly).

Windows defaults to the existing MSVC build. To use MinGW-built LLVM libraries
and tket instead, select the additional target explicitly:

```yaml
- name: Install hugrenv (MinGW)
  uses: Quantinuum/hugrverse-env/install-hugrenv-action@main
  with:
    packages: llvm,tket
    target: win_mingw_amd64
```

Both MinGW archives use the same GCC 14.2.0 distribution pinned by URL and
SHA-256 in `mingw-toolchain.json`, with POSIX threads, SEH and the MSVCRT runtime.
They include the GNU runtime DLLs, their licence notices and the compiler's
build information. Consumers linking C++ libraries should use a compatible
MinGW toolchain. The `hugrenv.lock` hashes for this target are recorded under
`hashes.win_mingw.amd64`.

```yaml
- name: Install hugrenv (wasm)
  uses: Quantinuum/hugrverse-env/install-hugrenv-action@main
  with:
    packages: tket
    # Use emscripten_4_0_9_wasm32 for pyemscripten_2025_0.
    target: emscripten_5_0_3_wasm32
```

## How CI works

1. **Build** (`build.yml`) — triggered on pull requests and manually via
   `workflow_dispatch`.
   * On a PR, only scripts that changed since the base commit are built.
   * A manual run rebuilds every target. After it succeeds, `merge.yml`
     automatically promotes the fresh artifacts for the next release.
   * Linux targets are built inside the official `quay.io/pypa/manylinux_2_28_*`
     Docker images to ensure manylinux binary compatibility.
   * macOS targets run natively; `MACOSX_DEPLOYMENT_TARGET` is set to `11.0`.
   * `win_amd64` uses the MSVC toolchain via `ilammy/msvc-dev-cmd`.
   * `win_mingw_amd64` installs the pinned MinGW distribution. Changing the pin
     rebuilds both packages and invalidates their caches. Both packages
     build and run a small consumer of the installed libraries before archiving
     them, and check that the packaged binaries don't import the MSVC C++ runtime.
   * Each built archive is uploaded as a PR artifact named
     `pr-<head-sha>-<dep>-<platform>`.

2. **Merge** (`merge.yml`) — triggered when a PR is merged to `main`, and called
   as a reusable workflow by a successful manually dispatched full build.
   * Finds the build artifacts by commit SHA and re-uploads them as
     `main-<dep>-<platform>` artifacts (retained 90 days).

3. **Release** (`release.yml`) — triggered manually via `workflow_dispatch`.
   * Downloads all `main-*` promoted artifacts.
   * Generates a `hugrenv.lock` containing the version and Nix-style SHA-256
     hashes for every archive.
   * Checks that LLVM and tket's MinGW runtime DLLs and compiler build information
     match before combining them in a release.
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
