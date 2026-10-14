#!/usr/bin/env bash
set -euo pipefail

TAG_TKET="2.16.0"
TAG_BOOST="1.90.0"
TAG_SYMENGINE="v0.14.0"
TAG_EIGEN="5.0.1"
TAG_NLOHMANN_JSON="3.12.0"
TAG_CATCH2="3.13.0"

MINGW_ROOT="$(cygpath -u "${MINGW_ROOT:-C:/mingw64}")"
OUTPUT_TARBALL="$(cygpath -u "$1")"
# Use long Windows paths because Boost's install rules compare these paths.
BASE_DIR="$(cygpath -u "$(cygpath -w -l /tmp)")/tket-mingw"
SRC_DIR="${BASE_DIR}/src"
INSTALL_PREFIX="${BASE_DIR}/hugrverse"
export PATH="${MINGW_ROOT}/bin:${PATH}"
export CC="${MINGW_ROOT}/bin/gcc.exe"
export CXX="${MINGW_ROOT}/bin/g++.exe"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
test "$("${CC}" -dumpmachine)" = x86_64-w64-mingw32
mkdir -p "${SRC_DIR}" "${INSTALL_PREFIX}"

download() {
    local name="$1" url="$2" compression="$3"
    mkdir -p "${SRC_DIR}/${name}"
    curl -fsSL "${url}" | tar --strip-components=1 "-x${compression}" -f - -C "${SRC_DIR}/${name}"
}

echo "::group::Downloading sources"
download tket "https://github.com/Quantinuum/tket/archive/refs/tags/v${TAG_TKET}.tar.gz" z
download boost "https://github.com/boostorg/boost/releases/download/boost-${TAG_BOOST}/boost-${TAG_BOOST}-cmake.tar.xz" J
download symengine "https://github.com/symengine/symengine/archive/refs/tags/${TAG_SYMENGINE}.tar.gz" z
download eigen "https://gitlab.com/libeigen/eigen/-/archive/${TAG_EIGEN}/eigen-${TAG_EIGEN}.tar.bz2" j
download nlohmann_json "https://github.com/nlohmann/json/releases/download/v${TAG_NLOHMANN_JSON}/json.tar.xz" J
download catch2 "https://github.com/catchorg/Catch2/archive/refs/tags/v${TAG_CATCH2}.tar.gz" z
echo "::endgroup::"

build_install() {
    local source="$1"
    shift
    cmake -S "${source}" -B "${source}/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$(cygpath -m "${CC}")" \
        -DCMAKE_CXX_COMPILER="$(cygpath -m "${CXX}")" \
        -DCMAKE_INSTALL_PREFIX="$(cygpath -m "${INSTALL_PREFIX}")" \
        -DCMAKE_PREFIX_PATH="$(cygpath -m "${INSTALL_PREFIX}")" \
        -DCMAKE_CXX_STANDARD=14 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_FLAGS="-Wa,-mbig-obj" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DCMAKE_INSTALL_MESSAGE=NEVER \
        "$@"
    cmake --build "${source}/build"
    cmake --install "${source}/build"
}

echo "::group::Installing dependencies"
build_install "${SRC_DIR}/boost" -DBOOST_INSTALL_LAYOUT=system
sed -i 's/cmake_minimum_required(VERSION 2.8.12)/cmake_minimum_required(VERSION 3.5)/g' \
    "${SRC_DIR}/symengine/cmake/SymEngineConfig.cmake.in"
build_install "${SRC_DIR}/symengine" \
    -DBUILD_TESTS=OFF -DBUILD_BENCHMARKS=OFF \
    -DWITH_SYMENGINE_THREAD_SAFE=ON -DINTEGER_CLASS=boostmp -DWITH_GMP=OFF -DWITH_MPFR=OFF
build_install "${SRC_DIR}/eigen" \
    -DEIGEN_BUILD_TESTING=OFF -DEIGEN_BUILD_BLAS=OFF -DEIGEN_BUILD_LAPACK=OFF \
    -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_DEMOS=OFF -DEIGEN_BUILD_PKGCONFIG=OFF \
    -DEIGEN_BUILD_CMAKE_PACKAGE=ON
build_install "${SRC_DIR}/nlohmann_json" -DJSON_BuildTests=OFF
build_install "${SRC_DIR}/catch2" -DCATCH_BUILD_TESTING=OFF
echo "::endgroup::"

echo "::group::Building tket with MinGW"
# These two upstream flag blocks assume every Windows compiler is MSVC.
# Guard the MSVC flags by compiler, while keeping Windows DLL exports enabled.
sed -i '/IF (WIN32)/{N; /CMAKE_CXX_FLAGS/s/IF (WIN32)/IF (MSVC)/;P;D;}' \
    "${SRC_DIR}/tket/tket/CMakeLists.txt"
sed -i 's/if (WIN32)/if (MSVC)/g' "${SRC_DIR}/tket/tket-c-api/CMakeLists.txt"
for library in tklog tkrng tkassert tkwsm tktokenswap; do
    build_install "${SRC_DIR}/tket/libs/${library}"
done
build_install "${SRC_DIR}/tket/tket"

api_source="${SRC_DIR}/tket/tket-c-api"
# SymEngine uses boostmp here, so the C API shouldn't try to find GMP.
sed -i.bak -E '
    /find_package\(gmp CONFIG\)/d;
    /if \(NOT gmp_FOUND\)/,/endif\(\)/d;
    /if \(NOT TARGET gmp::gmp\)/,/endif\(\)/d;
' "${api_source}/CMakeLists.txt"
cat >> "${api_source}/CMakeLists.txt" <<'CMAKE'

# These dependencies are private to tket, so we also link them in the C API.
target_link_libraries(tket-c-api PRIVATE Boost::headers nlohmann_json::nlohmann_json symengine::symengine tkassert::tkassert tklog::tklog tkrng::tkrng tktokenswap::tktokenswap)
CMAKE
build_install "${api_source}" -DBUILD_SHARED_LIBS=ON
echo "::endgroup::"

echo "::group::Packaging MinGW runtime dependencies"
mkdir -p "${INSTALL_PREFIX}/bin" "${INSTALL_PREFIX}/share/mingw"
for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
    cp "${MINGW_ROOT}/bin/${dll}" "${INSTALL_PREFIX}/bin/"
done
for component in gcc mingw-w64 winpthreads; do
    cp -R "${MINGW_ROOT}/licenses/${component}" "${INSTALL_PREFIX}/share/mingw/"
done
cp "${MINGW_ROOT}/build-info.txt" "${INSTALL_PREFIX}/share/mingw/"
echo "::endgroup::"

echo "::group::Checking a MinGW consumer of the installed tket C API"
cat > "${BASE_DIR}/consumer.c" <<'C'
#include <tket-c-api.h>
#include <string.h>
int main(void) {
    const char *message = tket_error_string(TKET_SUCCESS);
    return message && strlen(message) ? 0 : 1;
}
C
"${CC}" "${BASE_DIR}/consumer.c" -o "${BASE_DIR}/consumer.exe" \
    -I"${INSTALL_PREFIX}/include" -L"${INSTALL_PREFIX}/lib" -ltket-c-api
export PATH="${INSTALL_PREFIX}/bin:${PATH}"
"${BASE_DIR}/consumer.exe"
while IFS= read -r -d '' binary; do
    imports=$("${MINGW_ROOT}/bin/objdump.exe" -p "${binary}")
    if grep -Ei 'DLL Name: (vcruntime|msvcp)[^[:space:]]*\.dll' <<< "${imports}"; then
        echo "Unexpected MSVC runtime dependency in ${binary}" >&2
        exit 1
    fi
done < <(find "${INSTALL_PREFIX}" -type f -name '*.dll' -print0)
echo "::endgroup::"

tar -czf "${OUTPUT_TARBALL}" -C "${BASE_DIR}" hugrverse
