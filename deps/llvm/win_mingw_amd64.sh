#!/usr/bin/env bash
# Build a separate MinGW LLVM distribution alongside the MSVC Windows build.
set -euo pipefail

LLVM_VERSION="21.1.8"
LLVM_TAG="llvmorg-${LLVM_VERSION}"
MINGW_ROOT="$(cygpath -u "${MINGW_ROOT:-C:/mingw64}")"
OUTPUT_TARBALL="$(cygpath -u "$1")"
BASE_DIR="$(cygpath -u "$(cygpath -w -l /tmp)")/llvm-mingw"
INSTALL_PREFIX="${BASE_DIR}/hugrverse"
SOURCE_TARBALL="llvm-project-${LLVM_VERSION}.src.tar.xz"
SOURCE_DIR="${BASE_DIR}/llvm-project-${LLVM_VERSION}.src"

export PATH="${MINGW_ROOT}/bin:${PATH}"
export CC="${MINGW_ROOT}/bin/gcc.exe"
export CXX="${MINGW_ROOT}/bin/g++.exe"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
test "$("${CC}" -dumpmachine)" = x86_64-w64-mingw32
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"

echo "::group::Downloading LLVM ${LLVM_VERSION} source"
curl -fsSL -o "${SOURCE_TARBALL}" \
    "https://github.com/llvm/llvm-project/releases/download/${LLVM_TAG}/${SOURCE_TARBALL}"
command /c/Windows/System32/tar.exe -xf "${SOURCE_TARBALL}"
echo "::endgroup::"

echo "::group::Building LLVM with MinGW"
cmake -S "${SOURCE_DIR}/llvm" -B "${BASE_DIR}/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$(cygpath -m "${CC}")" \
    -DCMAKE_CXX_COMPILER="$(cygpath -m "${CXX}")" \
    -DCMAKE_INSTALL_PREFIX="$(cygpath -m "${INSTALL_PREFIX}")" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
    -DLLVM_PARALLEL_LINK_JOBS=1 \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF
cmake --build "${BASE_DIR}/build" --target install
echo "::endgroup::"

echo "::group::Packaging MinGW runtime dependencies"
mkdir -p "${INSTALL_PREFIX}/share/mingw"
for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
    cp "${MINGW_ROOT}/bin/${dll}" "${INSTALL_PREFIX}/bin/"
done
for component in gcc mingw-w64 winpthreads; do
    cp -R "${MINGW_ROOT}/licenses/${component}" "${INSTALL_PREFIX}/share/mingw/"
done
cp "${MINGW_ROOT}/build-info.txt" "${INSTALL_PREFIX}/share/mingw/"
echo "::endgroup::"

echo "::group::Checking the installed LLVM tools and C++ libraries"
export PATH="${INSTALL_PREFIX}/bin:${PATH}"
"${INSTALL_PREFIX}/bin/llc.exe" --version
"${INSTALL_PREFIX}/bin/ld.lld.exe" --version
mkdir -p "${BASE_DIR}/consumer"
cat > "${BASE_DIR}/consumer/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.21)
project(LLVMConsumer LANGUAGES C CXX)
find_package(LLVM REQUIRED CONFIG)
add_executable(llvm-consumer main.cpp)
target_compile_features(llvm-consumer PRIVATE cxx_std_17)
target_include_directories(llvm-consumer SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})
if(NOT LLVM_ENABLE_RTTI)
    target_compile_options(llvm-consumer PRIVATE -fno-rtti)
endif()
llvm_map_components_to_libnames(llvm_libraries Core IRReader Support)
target_link_libraries(llvm-consumer PRIVATE ${llvm_libraries})
CMAKE
cat > "${BASE_DIR}/consumer/main.cpp" <<'CPP'
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/MemoryBuffer.h"
int main() {
    llvm::LLVMContext context;
    llvm::SMDiagnostic diagnostic;
    auto buffer = llvm::MemoryBuffer::getMemBuffer("define i32 @main() { ret i32 0 }");
    auto module = llvm::parseIR(buffer->getMemBufferRef(), diagnostic, context);
    return module ? 0 : 1;
}
CPP
cmake -S "${BASE_DIR}/consumer" -B "${BASE_DIR}/consumer/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$(cygpath -m "${CC}")" \
    -DCMAKE_CXX_COMPILER="$(cygpath -m "${CXX}")" \
    -DLLVM_DIR="$(cygpath -m "${INSTALL_PREFIX}/lib/cmake/llvm")"
cmake --build "${BASE_DIR}/consumer/build"
"${BASE_DIR}/consumer/build/llvm-consumer.exe"
# We expect Windows system DLLs, but no redistributable MSVC C++ runtime.
while IFS= read -r -d '' binary; do
    imports=$("${MINGW_ROOT}/bin/objdump.exe" -p "${binary}")
    if grep -Ei 'DLL Name: (vcruntime|msvcp)[^[:space:]]*\.dll' <<< "${imports}"; then
        echo "Unexpected MSVC runtime dependency in ${binary}" >&2
        exit 1
    fi
done < <(find "${INSTALL_PREFIX}" -type f \( -name '*.exe' -o -name '*.dll' \) -print0)
echo "::endgroup::"

tar -czf "${OUTPUT_TARBALL}" -C "${BASE_DIR}" hugrverse
