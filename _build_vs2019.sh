#!/bin/bash
TARGET=zlib_1_3_11
TARGET_CMAKE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET_SOURCE_DIR=${TARGET_CMAKE_DIR}

# you need export : "ARCH", "ROOT_DIR",
# option dir: "INSTALL_DIR", "BUILD_GEN_DIR" "UPLOAD_URL"  "RUNTIME_DIR"
__arch=
__root_dir=
__install_dir=
__build_gen_dir=
__upload_url=
__runtime_dir=

if [ -n "${ARCH}" ]; then
   __arch=${ARCH}
else
   __arch="x64"
fi

if [ -n "${ROOT_DIR}" ]; then
   __root_dir=${ROOT_DIR}
else
   __root_dir=${TARGET_CMAKE_DIR}
fi

if [ -n "${INSTALL_DIR}" ]; then
   __install_dir=${INSTALL_DIR}
else
   __install_dir=${__root_dir}/install/vs2019/sdk
fi

if [ -n "${BUILD_GEN_DIR}" ]; then
   __build_gen_dir=${BUILD_GEN_DIR}
else
   __build_gen_dir=${__root_dir}/build_generated/vs2019
fi

if [ -n "${UPLOAD_URL}" ]; then
   __upload_url=${UPLOAD_URL}
fi

if [ -n "${RUNTIME_DIR}" ]; then
   __runtime_dir=${RUNTIME_DIR}
elif [ -n "${ROOT_DIR}" ]; then
   __runtime_dir=${ROOT_DIR}/install/vs2019/runtime
fi

__package_dir=${__install_dir}/package


echo TARGET_CMAKE_DIR:$TARGET_CMAKE_DIR
echo TARGET_SOURCE_DIR:${TARGET_SOURCE_DIR}
echo INSTALL_DIR:${__install_dir}
echo BUILD_GENERATE_DIR:${__build_gen_dir}

echo "*** start build ${TARGET} ***"
   
install_path="${__install_dir}/${TARGET}"
build_path="${__build_gen_dir}/${TARGET}"

echo "install_path=${install_path}"
echo "build_path=${build_path}"

# rm exsit install
if [ -e "${install_path}" ]; then
   rm -rf ${install_path}
fi
# rm exsit generated
if [ -e "${build_path}" ]; then
   rm -rf ${build_path}
fi

# make generated dir
mkdir -p  ${build_path}

cd ${build_path}

cmake -G "Visual Studio 16 2019" \
   -A "${__arch}" \
   -DZLIB_BUILD_EXAMPLES=OFF \
   -DCMAKE_CONFIGURATION_TYPES="Debug;Release;RelWithDebInfo" \
   -DCMAKE_INSTALL_PREFIX="${install_path}" \
   -DINSTALL_BIN_DIR="$<CONFIGURATION>/bin" \
   -DINSTALL_LIB_DIR="$<CONFIGURATION>/lib" \
   -DINSTALL_INC_DIR="include" \
   -DINSTALL_MAN_DIR="share/man" \
   -DINSTALL_PKGCONFIG_DIR="share/pkgconfig" \
   ${TARGET_SOURCE_DIR} || exit 1


cmake --build . --target install --config Debug -- /maxcpucount:8 || exit 1
cmake --build . --target install --config Release -- /maxcpucount:8 || exit 1
cmake --build . --target install --config RelWithDebInfo -- /maxcpucount:8 || exit 1

rm -rf ${install_path}/share

echo "*** build finised ${TARGET} ***"

if [ -n "${__upload_url}" ]; then

   echo "=== start upload ${TARGET} ==="

   cd ${__install_dir}

   set -e

   tar -czvf ${TARGET}.tar.gz ${TARGET}

   shasum -a 256 ${TARGET}.tar.gz > ${TARGET}.tar.gz.sha256

   curl --insecure --ftp-create-dirs -T ${TARGET}.tar.gz ${__upload_url}
   curl --insecure --ftp-create-dirs -T ${TARGET}.tar.gz.sha256 ${__upload_url}

   echo "=== upload finished ${TARGET} ==="
fi

# copy runtime bin files
if [ -n "${__runtime_dir}" ]; then

   echo "=== start copy ${TARGET} runtime files ==="

   _BUILD_TYPES=("Debug" "Release" "RelWithDebInfo")

   for build_type in "${_BUILD_TYPES[@]}" ; do
      if [ -e "${install_path}/${build_type}/bin" ]; then
         for _filepath in ${install_path}/${build_type}/bin/*.dll; do
            if [ -f "$_filepath" ]; then
               cp --verbose -rf "$_filepath" "$__runtime_dir/${build_type}/bin"
            fi
         done

         for _filepath in ${install_path}/${build_type}/bin/*.pdb; do
            if [ -f "$_filepath" ]; then
               cp --verbose -rf "$_filepath" "$__runtime_dir/${build_type}/bin"
            fi
         done
      fi
   done

   echo "=== finished copy ${TARGET} runtime files ==="
fi






