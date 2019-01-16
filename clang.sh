#!/bin/bash
kernel_dir=$PWD
export V="v1.5"
export CONFIG_FILE="sg_defconfig"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=Zaheer
export KBUILD_BUILD_HOST=Pasar
export TOOL_CHAIN_PATH="/mnt/d/markw/archgcc/bin/aarch64-linux-android-"
export CLANG_TCHAIN="/mnt/d/markw/dragontc/bin/clang"
export CLANG_VERSION="$(${CLANG_TCHAIN} --version | head -n 1 | cut -d'(' -f1,4)"
export LD_LIBRARY_PATH="${TOOL_CHAIN_PATH}/../lib"
#export PATH=$PATH:${TOOL_CHAIN_PATH}
export builddir="${kernel_dir}/mateng"
#export modules_dir="zip/system/lib/modules"
export ZIPPER_DIR="${kernel_dir}/zip"
export ZIP_NAME="wayang™${V}_Oreo-Los_Aosp.zip"
export IMAGE="arch/arm64/boot/Image.gz-dtb";
JOBS="-j8"
cd $kernel_dir


make_a_fucking_defconfig() {
	make $CONFIG_FILE
}

compile() {
	PATH=${BIN_FOLDER}:${PATH} make \
	O=${out_dir} \
	CC="${CLANG_TCHAIN}" \
	CLANG_TRIPLE=aarch64-linux-gnu- \
	CROSS_COMPILE=${TOOL_CHAIN_PATH} \
    KBUILD_COMPILER_STRING="${CLANG_VERSION}" \
	HOSTCC="${CLANG_TCHAIN}" \
    $JOBS
}

zipit () {
    if [[ ! -f "${IMAGE}" ]]; then
        echo -e "Build failed :P";
        exit 1;
    else
        echo -e "Build Succesful!";
    fi
    echo "**** Copying zImage ****"
    cp arch/arm64/boot/Image.gz-dtb ${ZIPPER_DIR}/tools/
    echo "**** Copying modules ****"

    cd ${ZIPPER_DIR}/
    zip -r9 ${ZIP_NAME} * -x README ${ZIP_NAME}
    rm -rf ${kernel_dir}/mateng/${ZIP_NAME}
    mv ${ZIPPER_DIR}/${ZIP_NAME} ${kernel_dir}/mateng/${ZIP_NAME}
}

make_a_fucking_defconfig
compile
zipit
cd ${kernel_dir}
