set -evu

# Builds the tket C API and its C++ dependencies for the Emscripten/WebAssembly
# target (`wasm32-unknown-emscripten`).
#
# The output is consumed when building `wasm32-unknown-emscripten` Python wheels
# for tket2 (Pyodide / PyEmscripten). We pin Emscripten to the version used by
# the `pyemscripten_2026_0` platform (Python 3.14):
#   https://pyodide.org/en/stable/development/abi.html
#
# Unlike the native targets, everything is built as a *static* library and the
# individual archives are merged into a single `libtket-c-api.a` so that
# downstream consumers can keep linking against just `-ltket-c-api`.

TAG_TKET="2.16.0"
TAG_BOOST="1.90.0"
TAG_SYMENGINE="v0.14.0"
TAG_EIGEN="5.0.1"
TAG_NLOHMANN_JSON="3.12.0"
TAG_CATCH2="3.13.0"

# Emscripten version matching the `pyemscripten_2026_0` platform (Python 3.14).
TAG_EMSCRIPTEN="5.0.3"

BASE_DIR=/tmp
INSTALL_CHILD=hugrverse
INSTALL_PREFIX="${BASE_DIR}/${INSTALL_CHILD}"
SRC_DIR=/tmp/src
OUTPUT_TARBALL="$1"

CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
export CMAKE_BUILD_PARALLEL_LEVEL

# ABI-sensitive flags required by the PyEmscripten platform:
#   - `-fwasm-exceptions` for WebAssembly exception handling (compile + link)
#   - `-sSUPPORT_LONGJMP=wasm` for WebAssembly setjmp/longjmp
#   - no `-pthread`: threads are unsupported and break loading
# tket's CMake files compile with `-Werror`; Emscripten's clang surfaces a few
# extra warnings, so we downgrade them to keep the build going.
#
# `-DBOOST_HAS_PTHREADS` forces Boost to use its pthread-based primitives (which
# resolve against Emscripten's single-threaded pthread stubs) instead of falling
# back to the Windows implementation, which does not compile here.
WASM_CXX_FLAGS="-fwasm-exceptions -sSUPPORT_LONGJMP=wasm -fPIC -Wno-error -DBOOST_HAS_PTHREADS"
WASM_C_FLAGS="-fPIC -Wno-error"
WASM_EXE_LINKER_FLAGS="-fwasm-exceptions -sSUPPORT_LONGJMP=wasm"

mkdir -p ${SRC_DIR}
mkdir -p ${INSTALL_PREFIX}

echo "::group::Setting up the Emscripten SDK @ ${TAG_EMSCRIPTEN}"
    git clone --depth 1 https://github.com/emscripten-core/emsdk.git ${SRC_DIR}/emsdk
    cd ${SRC_DIR}/emsdk
    ./emsdk install ${TAG_EMSCRIPTEN}
    ./emsdk activate ${TAG_EMSCRIPTEN}
    # shellcheck disable=SC1091
    source ${SRC_DIR}/emsdk/emsdk_env.sh
echo "::endgroup::"

# Common cmake invocation for the Emscripten toolchain.
#   `emcmake` injects the Emscripten toolchain file and compilers. That toolchain
#   restricts `find_package`/`find_library`/`find_path` to the Emscripten sysroot,
#   so we add our install prefix to `CMAKE_FIND_ROOT_PATH` and allow searching it.
emcmake_configure() {
    emcmake cmake \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
        -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
        -DCMAKE_FIND_ROOT_PATH=${INSTALL_PREFIX} \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_INSTALL_MESSAGE=NEVER \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_FLAGS="${WASM_CXX_FLAGS}" \
        -DCMAKE_C_FLAGS="${WASM_C_FLAGS}" \
        -DCMAKE_EXE_LINKER_FLAGS="${WASM_EXE_LINKER_FLAGS}" \
        "$@"
}

echo "::group::Downloading Sources"

    echo "::group::TKET @ ${TAG_TKET}"
    mkdir -p ${SRC_DIR}/tket
    curl -L https://github.com/Quantinuum/tket/archive/refs/tags/v${TAG_TKET}.tar.gz \
        | tar --strip-components=1 -xz -C ${SRC_DIR}/tket
    echo "::endgroup::"

    echo "::group::Boost @ ${TAG_BOOST}"
    mkdir -p ${SRC_DIR}/boost
    curl -L https://github.com/boostorg/boost/releases/download/boost-${TAG_BOOST}/boost-${TAG_BOOST}-cmake.tar.xz \
        | tar --strip-components=1 -xJ -C ${SRC_DIR}/boost
    echo "::endgroup::"

    echo "::group::SymEngine @ ${TAG_SYMENGINE}"
    mkdir -p ${SRC_DIR}/symengine
    curl -L https://github.com/symengine/symengine/archive/refs/tags/${TAG_SYMENGINE}.tar.gz \
        | tar --strip-components=1 -xz -C ${SRC_DIR}/symengine
    echo "::endgroup::"

    echo "::group::Eigen @ ${TAG_EIGEN}"
    mkdir -p ${SRC_DIR}/eigen
    curl -L https://gitlab.com/libeigen/eigen/-/archive/${TAG_EIGEN}/eigen-${TAG_EIGEN}.tar.bz2 \
        | tar --strip-components=1 -xj -C ${SRC_DIR}/eigen
    echo "::endgroup::"

    echo "::group::Nlohmann JSON @ ${TAG_NLOHMANN_JSON}"
    mkdir -p ${SRC_DIR}/nlohmann_json
    curl -L https://github.com/nlohmann/json/releases/download/v${TAG_NLOHMANN_JSON}/json.tar.xz \
        | tar --strip-components=1 -xJ -C ${SRC_DIR}/nlohmann_json
    echo "::endgroup::"

    echo "::group::Catch2 @ ${TAG_CATCH2}"
    mkdir -p ${SRC_DIR}/catch2
    curl -L https://github.com/catchorg/Catch2/archive/refs/tags/v${TAG_CATCH2}.tar.gz \
        | tar --strip-components=1 -xz -C ${SRC_DIR}/catch2
    echo "::endgroup::"

echo "::endgroup::"

echo "::group::Installing Dependencies"
    echo "::group::boost (headers only)"
        # tket and SymEngine only use header-only Boost (`Boost::headers` /
        # Boost.Multiprecision), so we avoid building any compiled Boost
        # libraries: several of them (e.g. Boost.Context) rely on
        # architecture-specific assembly that does not build under Emscripten.
        #
        # `BOOST_INCLUDE_LIBRARIES=headers` installs the CMake package config
        # (providing the `Boost::headers` target) without compiling anything,
        # then we copy the full modular header tree into the prefix by hand.
        cd ${SRC_DIR}/boost
        mkdir build
        cd build
        emcmake_configure \
            -DBOOST_INCLUDE_LIBRARIES=headers \
            ..
        cmake --build .
        cmake --install .

        find "${SRC_DIR}/boost/libs" -type d -name include | while IFS= read -r inc; do
            if [ -d "${inc}/boost" ]; then
                cp -R "${inc}/boost" "${INSTALL_PREFIX}/include/"
            fi
        done
    echo "::endgroup::"

    echo "::group::symengine"
        cd ${SRC_DIR}/symengine
        sed -i -e 's/cmake_minimum_required(VERSION 2.8.12)/cmake_minimum_required(VERSION 3.5)/g' cmake/SymEngineConfig.cmake.in
        mkdir build
        cd build
        # note: we disable gmp and mpfr to avoid having to build them, and instead use boost's multiprecision.
        # SymEngine uses the classic (non-CONFIG) FindBoost, so point it at the header prefix explicitly.
        # We also disable thread safety since threads are unsupported on Emscripten.
        emcmake_configure \
            -DBOOST_ROOT=${INSTALL_PREFIX} \
            -DBoost_INCLUDE_DIR=${INSTALL_PREFIX}/include \
            -DBUILD_TESTS=OFF \
            -DBUILD_BENCHMARKS=OFF \
            -DWITH_SYMENGINE_THREAD_SAFE=OFF \
            -DINTEGER_CLASS=boostmp \
            -DWITH_GMP=OFF \
            -DWITH_MPFR=OFF \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::eigen"
        cd ${SRC_DIR}/eigen
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::nlohmann_json"
        cd ${SRC_DIR}/nlohmann_json
        mkdir build
        cd build
        emcmake_configure \
            -DJSON_BuildTests=OFF \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::catch2"
        cd ${SRC_DIR}/catch2
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"


echo "::endgroup::"
echo "::group::Installing tket and tket-c-api ===="

    # Emscripten's clang rejects the empty-brace initialisation of the
    # `parents_neighbours` map value in tket 2.16.0. Spell out the pair type.
    # (see https://github.com/Quantinuum/tket/compare/main...jpacold:tket:emscripten)
    sed -i.bak -E \
        's/parents_neighbours\[vert\] = \{\};/parents_neighbours[vert] = std::pair<unsigned int, unsigned int>{};/' \
        "${SRC_DIR}/tket/tket/src/ArchAwareSynth/Path.cpp"

    # tket's CMake files append `-Werror` after our own `CMAKE_CXX_FLAGS`, so our
    # `-Wno-error` gets overridden. Emscripten's clang is stricter than the
    # native GCC builds (e.g. it flags extra `-Wsign-compare` cases), so strip
    # `-Werror` from every tket CMakeLists to keep those warnings non-fatal.
    find "${SRC_DIR}/tket" -name CMakeLists.txt -exec sed -i.werrorbak 's/ -Werror//g' {} +

    echo "::group::tklog"
        cd ${SRC_DIR}/tket/libs/tklog/
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::tkrng"
        cd ${SRC_DIR}/tket/libs/tkrng/
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::tkassert"
        cd ${SRC_DIR}/tket/libs/tkassert/
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::tkwsm"
        cd ${SRC_DIR}/tket/libs/tkwsm/
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::tktokenswap"
        cd ${SRC_DIR}/tket/libs/tktokenswap/
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::tket"
        cd "${SRC_DIR}/tket/tket"
        mkdir build
        cd build
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

    echo "::group::tket-c-api"
        cd "${SRC_DIR}/tket/tket-c-api"
        # avoid gmp
        sed -i.bak -E '
            /find_package\(gmp CONFIG\)/d;
            /if \(NOT gmp_FOUND\)/,/endif\(\)/d;
            /if \(NOT TARGET gmp::gmp\)/,/endif\(\)/d;
        ' CMakeLists.txt
        mkdir build
        cd build
        # Static build (unlike the native targets which build a shared library):
        # Emscripten side modules are not what downstream Rust wheels want, so we
        # produce a static archive and merge in the transitive dependencies below.
        emcmake_configure \
            ..
        cmake --build .
        cmake --install .
    echo "::endgroup::"

echo "::endgroup::"

echo "::group::Merging static archives into libtket-c-api.a"
    # tket-c-api only PRIVATE-links its dependencies, so the installed
    # `libtket-c-api.a` does not contain the tket / tk* / symengine / boost
    # object code. Merge every relevant archive into a single self-contained
    # `libtket-c-api.a` so downstream wheels link with just `-ltket-c-api`.
    #
    # We deliberately exclude Catch2 (test framework, ships a `main`) and its
    # variants.
    LIB_DIRS="${INSTALL_PREFIX}/lib ${INSTALL_PREFIX}/lib64"
    MERGE_DIR="${SRC_DIR}/merge"
    mkdir -p "${MERGE_DIR}"
    cd "${MERGE_DIR}"

    archives=""
    for dir in ${LIB_DIRS}; do
        [ -d "${dir}" ] || continue
        for archive in "${dir}"/*.a; do
            [ -e "${archive}" ] || continue
            case "$(basename "${archive}")" in
                libCatch2*.a) continue ;;
            esac
            archives="${archives} ${archive}"
        done
    done

    {
        echo "create libtket-c-api.a"
        for archive in ${archives}; do
            echo "addlib ${archive}"
        done
        echo "save"
        echo "end"
    } | emar -M

    # Replace the thin per-target archive with the merged one in every lib dir
    # that originally held it.
    for dir in ${LIB_DIRS}; do
        if [ -f "${dir}/libtket-c-api.a" ]; then
            cp "${MERGE_DIR}/libtket-c-api.a" "${dir}/libtket-c-api.a"
            emranlib "${dir}/libtket-c-api.a"
        fi
    done
echo "::endgroup::"

echo "::group::Compressing installation to output tarball"
    tar -czvf "${OUTPUT_TARBALL}" -C "${BASE_DIR}" "${INSTALL_CHILD}"
echo "::endgroup::"
