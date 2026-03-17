#!/usr/bin/env bash
# Build LLVM 21.1.0 from source for macosx_15_0_arm64.
# Installs to /opt/llvm.
set -euo pipefail

LLVM_VERSION="21.1.0"
LLVM_TAG="llvmorg-${LLVM_VERSION}"
INSTALL_PREFIX="/opt/llvm"
BUILD_DIR="/tmp/llvm-build"
TARBALL="llvm-project-${LLVM_VERSION}.src.tar.xz"

echo "=== Installing build dependencies ==="
brew install cmake ninja xz

echo "=== Downloading LLVM ${LLVM_VERSION} source ==="
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

if [ ! -f "${TARBALL}" ]; then
    curl -fsSL -o "${TARBALL}" \
        "https://github.com/llvm/llvm-project/releases/download/${LLVM_TAG}/${TARBALL}"
fi

echo "=== Extracting source ==="
SOURCE_DIR="llvm-project-${LLVM_VERSION}.src"
if [ ! -d "${SOURCE_DIR}" ]; then
    tar xf "${TARBALL}"
fi

echo "=== Configuring LLVM ==="
mkdir -p "${BUILD_DIR}/build"
cmake \
    -S "${BUILD_DIR}/${SOURCE_DIR}/llvm" \
    -B "${BUILD_DIR}/build" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="AArch64" \
    -DLLVM_BUILD_TOOLS=ON \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_ENABLE_ZLIB=FORCE_ON \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF

echo "=== Building and installing LLVM (this may take a while) ==="
sudo cmake --build "${BUILD_DIR}/build" --target install -- -j"$(sysctl -n hw.logicalcpu)"

echo "=== LLVM ${LLVM_VERSION} installed to ${INSTALL_PREFIX} ==="
