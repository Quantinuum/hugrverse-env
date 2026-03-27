set -evu

TAG_TKET="2.16.0"
TAG_BOOST="1.90.0"
TAG_SYMENGINE="v0.14.0"
TAG_EIGEN="5.0.1"
TAG_NLOHMANN_JSON="3.12.0"
TAG_CATCH2="3.13.0"

SRC_DIR=/tmp/src
INSTALL_PREFIX=/tmp/hugrverse
OUTPUT_TARBALL="$(cygpath -u "$1")"

CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
export CMAKE_BUILD_PARALLEL_LEVEL

mkdir -p ${SRC_DIR}
mkdir -p ${INSTALL_PREFIX}

echo "::group::Debug"
    echo "which cmake: $(which cmake)"
    echo "which cl: $(which cl)"
    echo "which c++: $(which c++)"
echo "::endgroup::"

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
    echo "::group::boost"
        cd ${SRC_DIR}/boost
        mkdir build
        cd build
        cmake \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            ..
        cmake --build . --config Release --config Release
        # Sometimes the installation step can fail due to transient file locking issues on Windows,
        # so we use a retry mechanism to try to beat it. It's that or build/install Boost single-threaded,
        # which is not ideal.
        for i in 1 2 3 4 5; do
            cmake --install . --config Release --config Release && break
            echo "Retrying installation (attempt $i)..."
            sleep 2
        done
    echo "::endgroup::"

    echo "::group::symengine"
        cd ${SRC_DIR}/symengine
        sed -i -e 's/cmake_minimum_required(VERSION 2.8.12)/cmake_minimum_required(VERSION 3.5)/g' cmake/SymEngineConfig.cmake.in
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DBUILD_TESTS=OFF \
            -DBUILD_BENCHMARKS=OFF \
            -DWITH_SYMENGINE_THREAD_SAFE=ON \
            -DINTEGER_CLASS=boostmp \
            -DWITH_GMP=OFF \
            -DWITH_MPFR=OFF \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::eigen"
        cd ${SRC_DIR}/eigen
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::nlohmann_json"
        cd ${SRC_DIR}/nlohmann_json
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DJSON_BuildTests=OFF \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::catch2"
        cd ${SRC_DIR}/catch2
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"


echo "::endgroup::"
echo "::group::Installing tket and tket-c-api ===="


    echo "::group::tklog"
        cd ${SRC_DIR}/tket/libs/tklog/
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=1 \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::tkrng"
        cd ${SRC_DIR}/tket/libs/tkrng/
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=1 \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::tkassert"
        cd ${SRC_DIR}/tket/libs/tkassert/
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=1 \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::tkwsm"
        cd ${SRC_DIR}/tket/libs/tkwsm/
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=1 \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::tktokenswap"
        cd ${SRC_DIR}/tket/libs/tktokenswap/
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=1 \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::tket"
        cd "${SRC_DIR}/tket/tket"
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=1 \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

    echo "::group::tket-c-api"
        cd "${SRC_DIR}/tket/tket-c-api"
        mkdir build
        cd build
        cmake \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=1 \
            ..
        cmake --build . --config Release
        cmake --install . --config Release
    echo "::endgroup::"

echo "::endgroup::"

echo "::group::Compressing LLVM installation to output tarball"
    tar -czvf "${OUTPUT_TARBALL}" ${INSTALL_PREFIX}
echo "::endgroup::"
