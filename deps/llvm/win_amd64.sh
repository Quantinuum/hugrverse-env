# Build LLVM 21.1.8 from source for windows
set -euo pipefail

LLVM_VERSION="21.1.8"
LLVM_TAG="llvmorg-${LLVM_VERSION}"
BASE_DIR="/tmp"
INSTALL_CHILD="hugrverse"
INSTALL_PREFIX="${BASE_DIR}/${INSTALL_CHILD}"
BUILD_DIR="/tmp/llvm-build"
SOURCE_TARBALL="/tmp/llvm-project-${LLVM_VERSION}.src.tar.xz"
SOURCE_DIR="/tmp/llvm-project-${LLVM_VERSION}.src"

OUTPUT_TARBALL="$(cygpath -u "$1")"

CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
CC=cl
CXX=cl
export CMAKE_BUILD_PARALLEL_LEVEL
export CC
export CXX

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
        # use windows tar instead of tar from msys2 to avoid issues with symlinks
        command /c/Windows/System32/tar.exe -xf "${SOURCE_TARBALL}"
    fi
echo "::endgroup::"

echo "::group::Configuring LLVM"
    mkdir -p "${BUILD_DIR}/build"
    cmake \
        -S "${BUILD_DIR}/${SOURCE_DIR}/llvm" \
        -B "${BUILD_DIR}/build" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
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
    cmake --build "${BUILD_DIR}/build" --target install
echo "::endgroup::"


echo "::group::Compressing LLVM installation at '${INSTALL_PREFIX}' to output tarball '${OUTPUT_TARBALL}'"
    tar -czvf "${OUTPUT_TARBALL}" -C "${BASE_DIR}" "${INSTALL_CHILD}"
echo "::endgroup::"
