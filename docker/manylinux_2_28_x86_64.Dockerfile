# Dockerfile for running the manylinux_2_28_x86_64 build locally.
#
# Build image:
#   docker build -f docker/manylinux_2_28_x86_64.Dockerfile -t hugrverse-env-manylinux-x86_64 .
#
# Run build (output written to ./artifacts/):
#   mkdir -p artifacts
#   docker run --rm \
#       -v "$(pwd):/host" \
#       hugrverse-env-manylinux-x86_64 \
#       /host/builds/manylinux_2_28_x86_64/build.sh \
#       /host/artifacts/hugrverse_env_manylinux_2_28_x86_64.tar.gz
FROM quay.io/pypa/manylinux_2_28_x86_64

# curl is needed by the build scripts; it is typically pre-installed in the
# manylinux image but we install it explicitly for safety.
RUN dnf install -y curl && dnf clean all

# The repository is mounted at runtime (see usage above), so we do not COPY
# anything here. The entry point is set to bash so that any script path can be
# passed as a CMD argument.
ENTRYPOINT ["/bin/bash"]
