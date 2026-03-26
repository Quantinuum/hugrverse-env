set -evu

TAG_TKET="2.16.0"
TAG_BOOST="1.90.0"
TAG_SYMENGINE="v0.14.0"
TAG_EIGEN="5.0.1"
TAG_NLOHMANN_JSON="3.12.0"
TAG_CATCH2="3.13.0"
TAG_GMP="6.3.0"

SRC_DIR=/tmp/src
INSTALL_DIR=/tmp/hugrverse

CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
export CMAKE_BUILD_PARALLEL_LEVEL

mkdir -p ${SRC_DIR}
mkdir -p ${INSTALL_DIR}

echo "==== Downloading Sources ===="
echo " - tket @ ${TAG_TKET}"
mkdir -p ${SRC_DIR}/tket
curl -L https://github.com/Quantinuum/tket/archive/refs/tags/v${TAG_TKET}.tar.gz \
    | tar --strip-components=1 -xz -C ${SRC_DIR}/tket

echo " - boost @ ${TAG_BOOST}"
mkdir -p ${SRC_DIR}/boost
curl -L https://github.com/boostorg/boost/releases/download/boost-${TAG_BOOST}/boost-${TAG_BOOST}-cmake.tar.xz \
    | tar --strip-components=1 -xJ -C ${SRC_DIR}/boost

echo " - gmp @ ${TAG_GMP}"
mkdir -p ${SRC_DIR}/gmp
curl -L https://gmplib.org/download/gmp/gmp-${TAG_GMP}.tar.bz2 \
    | tar --strip-components=1 -xj -C ${SRC_DIR}/gmp

echo " - symengine @ ${TAG_SYMENGINE}"
mkdir -p ${SRC_DIR}/symengine
curl -L https://github.com/symengine/symengine/archive/refs/tags/${TAG_SYMENGINE}.tar.gz \
    | tar --strip-components=1 -xz -C ${SRC_DIR}/symengine

echo " - eigen @ ${TAG_EIGEN}"
mkdir -p ${SRC_DIR}/eigen
curl -L https://gitlab.com/libeigen/eigen/-/archive/${TAG_EIGEN}/eigen-${TAG_EIGEN}.tar.bz2 \
    | tar --strip-components=1 -xj -C ${SRC_DIR}/eigen

echo " - nlohmann_json @ ${TAG_NLOHMANN_JSON}"
mkdir -p ${SRC_DIR}/nlohmann_json
curl -L https://github.com/nlohmann/json/releases/download/v${TAG_NLOHMANN_JSON}/json.tar.xz \
    | tar --strip-components=1 -xJ -C ${SRC_DIR}/nlohmann_json

echo " - catch2 @ ${TAG_CATCH2}"
mkdir -p ${SRC_DIR}/catch2
curl -L https://github.com/catchorg/Catch2/archive/refs/tags/v${TAG_CATCH2}.tar.gz \
    | tar --strip-components=1 -xz -C ${SRC_DIR}/catch2



echo "==== Installing Dependencies ===="
echo " - boost"
cd ${SRC_DIR}/boost
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    ..
cmake --build .
cmake --install .

echo " - gmp"
cd ${SRC_DIR}/gmp
./configure --prefix=${INSTALL_DIR} --enable-cxx=yes
make -j$(nproc)
make install

echo " - symengine"
cd ${SRC_DIR}/symengine
sed -i -e 's/cmake_minimum_required(VERSION 2.8.12)/cmake_minimum_required(VERSION 3.5)/g' cmake/SymEngineConfig.cmake.in
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DBUILD_TESTS=OFF \
    -DBUILD_BENCHMARKS=OFF \
    -DWITH_SYMENGINE_THREAD_SAFE=ON \
    ..
cmake --build .
cmake --install .

echo " - eigen"
cd ${SRC_DIR}/eigen
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    ..
cmake --build .
cmake --install .

echo " - nlohmann_json"
cd ${SRC_DIR}/nlohmann_json
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DJSON_BuildTests=OFF \
    ..
cmake --build .
cmake --install .

echo " - catch2"
cd ${SRC_DIR}/catch2
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    ..
cmake --build .
cmake --install .


echo "==== Installing tket and tket-c-api ===="

echo " - tklog"
cd ${SRC_DIR}/tket/libs/tklog/
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=1 \
    ..
cmake --build .
cmake --install .

echo " - tkrng"
cd ${SRC_DIR}/tket/libs/tkrng/
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=1 \
    ..
cmake --build .
cmake --install .

echo " - tkassert"
cd ${SRC_DIR}/tket/libs/tkassert/
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=1 \
    ..
cmake --build .
cmake --install .

echo " - tkwsm"
cd ${SRC_DIR}/tket/libs/tkwsm/
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=1 \
    ..
cmake --build .
cmake --install .

echo " - tktokenswap"
cd ${SRC_DIR}/tket/libs/tktokenswap/
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=1 \
    ..
cmake --build .
cmake --install .

echo " - tket"
cd "${SRC_DIR}/tket/tket"
rm -rf build
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=1 \
    ..
cmake --build .
cmake --install .

echo " - tket-c-api"
cd "${SRC_DIR}/tket/tket-c-api"
rm -rf build
mkdir build
cd build
cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=1 \
    ..
cmake --build .
cmake --install .
