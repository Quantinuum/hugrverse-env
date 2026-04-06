# hugrverse-env

CI environment bootstrapping for hugrverse projects.

This repository builds and releases pre-compiled tooling environments used by
other repositories in the Quantinuum hugrverse. Each release contains a
compressed archive (`.tar.gz` or `.zip`) of pre-built tools for a specific
target platform. Downstream projects download these archives during their CI
bootstrap phase so that they never need to compile heavyweight dependencies
from scratch.

## What is built

| Component | Version | Description |
|-----------|---------|-------------|
| LLVM      | 21.1.8  | Clang + LLD + LLVM core libraries |

## Supported platforms

| Platform tag              | Runner                        | Archive format |
|---------------------------|-------------------------------|----------------|
| `manylinux_2_28_x86_64`   | Docker `quay.io/pypa/manylinux_2_28_x86_64` on `ubuntu-latest` | `.tar.gz` |
| `manylinux_2_28_aarch64`  | Docker `quay.io/pypa/manylinux_2_28_aarch64` on `ubuntu-24.04-arm` | `.tar.gz` |
| `macosx_11_0_aarch64`     | `macos-14`                    | `.tar.gz` |
| `macosx_11_0_x86_64`      | `macos-15-intel`              | `.tar.gz` |
| `win_amd64`               | `windows-latest` + MSVC       | `.zip` |

## Repository layout

```
builds/
  <platform>/        # One directory per target platform
    build.sh         # Parent script: builds all components, then bundles output
    version.txt      # Managed by release-please; records the current version
    llvm/
      build.sh       # Builds LLVM from source into /opt/llvm (or C:\hugrverse\llvm)
docker/
  manylinux_2_28_x86_64.Dockerfile   # Local-testing image for x86_64 Linux
  manylinux_2_28_aarch64.Dockerfile  # Local-testing image for AArch64 Linux
.github/
  workflows/
    build.yml             # Builds each platform; uploads artifact on release
    release-please.yml    # Creates release PRs and tags via release-please
release-please-config.json       # Monorepo release-please configuration
.release-please-manifest.json    # Current version for each package
```

## How CI works

1. **Build workflow** (`build.yml`) — triggered on every pull request, push to
   `main`, published GitHub release, and manually via `workflow_dispatch`.  
   * Linux targets are built inside the official `quay.io/pypa/manylinux_2_28_*`
     Docker images to ensure binary compatibility with the manylinux ABI.
   * macOS targets run natively on the appropriate GitHub-hosted runners.
   * The Windows target runs with the MSVC toolchain on `windows-latest`.
   * On a release event the resulting archives are also uploaded directly to
     the GitHub release.

2. **Release workflow** (`release-please.yml`) — triggered on every push to
   `main`.  
   * Uses [release-please](https://github.com/googleapis/release-please) in
     monorepo mode with five independent packages, one per platform.
   * When commits affecting a platform directory are merged to `main`,
     release-please opens a release PR for that platform.
   * Merging the release PR creates a tag (e.g.
     `hugrverse-env-manylinux_2_28_x86_64-v1.2.3`) and a GitHub release.
   * The build workflow then triggers on the published release and attaches the
     compiled archive.

## Adding a new component

1. Create a `builds/<platform>/<component>/build.sh` (or `.ps1` for Windows)
   that downloads, compiles, and installs the component to `/opt/<component>`
   (or `C:\hugrverse\<component>` on Windows).
2. Call the new script from `builds/<platform>/build.sh` and, if needed, add
   the install directory to the `tar` / `Compress-Archive` invocation that
   creates the bundle.
3. Repeat for every platform that should include the component.

## Local development

See [DEVELOPMENT.md](DEVELOPMENT.md) for instructions on testing changes
locally using Docker.
