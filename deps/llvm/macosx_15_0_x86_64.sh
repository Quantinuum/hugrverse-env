#!/usr/bin/env bash
# Build LLVM 21.1.8 from source for macos
set -euo pipefail

LLVM_VERSION="21.1.8"
LLVM_TAG="llvmorg-${LLVM_VERSION}"
BASE_DIR="/tmp"
INSTALL_CHILD="hugrverse"
INSTALL_PREFIX="${BASE_DIR}/${INSTALL_CHILD}"
BUILD_DIR="/tmp/llvm-build"
SOURCE_TARBALL="llvm-project-${LLVM_VERSION}.src.tar.xz"
SOURCE_DIR="llvm-project-${LLVM_VERSION}.src"

OUTPUT_TARBALL="$1"


echo "::group::Installing build dependencies"
    brew install cmake xz
echo "::endgroup::"


echo "::group::Downloading LLVM ${LLVM_VERSION} source"
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    if [ ! -f "${SOURCE_TARBALL}" ]; then
        curl -fsSL -o "${SOURCE_TARBALL}" \
            "https://github.com/llvm/llvm-project/releases/download/${LLVM_TAG}/${SOURCE_TARBALL}"
    fi
echo "::endgroup::"


echo "::group::Extracting source"
    if [ ! -d "${SOURCE_DIR}" ]; then
        tar xf "${SOURCE_TARBALL}"
    fi
echo "::endgroup::"


echo "::group::Configuring LLVM"
    sudo mkdir -p "${INSTALL_PREFIX}"
    sudo chown "$(id -u):$(id -g)" "${INSTALL_PREFIX}"
    mkdir -p "${BUILD_DIR}/build"
    cmake \
        -S "${BUILD_DIR}/${SOURCE_DIR}/llvm" \
        -B "${BUILD_DIR}/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_ENABLE_ZLIB=OFF \
        -DLLVM_ENABLE_ZSTD=OFF \
        -DLLVM_ENABLE_LIBXML2=OFF
echo "::endgroup::"


echo "::group::Building and installing LLVM (this may take a while)"
    cmake --build "${BUILD_DIR}/build" --target install --parallel "$(sysctl -n hw.logicalcpu)"
echo "::endgroup::"


echo "::group::Compressing LLVM installation to output tarball"
    tar -czvf "${OUTPUT_TARBALL}" -C "${BASE_DIR}" "${INSTALL_CHILD}"
echo "::endgroup::"
