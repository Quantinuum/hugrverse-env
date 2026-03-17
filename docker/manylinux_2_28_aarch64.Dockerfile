# Dockerfile for running the manylinux_2_28_aarch64 build locally.
#
# Build image (must be run on an AArch64 host, or with QEMU binfmt registered):
#   docker build -f docker/manylinux_2_28_aarch64.Dockerfile -t hugrverse-env-manylinux-aarch64 .
#
# Run build (output written to ./artifacts/):
#   mkdir -p artifacts
#   docker run --rm \
#       -v "$(pwd):/host" \
#       hugrverse-env-manylinux-aarch64 \
#       /host/builds/manylinux_2_28_aarch64/build.sh \
#       /host/artifacts/hugrverse_env_manylinux_2_28_aarch64.tar.gz
FROM quay.io/pypa/manylinux_2_28_aarch64

RUN dnf install -y curl && dnf clean all

ENTRYPOINT ["/bin/bash"]
