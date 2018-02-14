#!/usr/bin/env bash
#
# Script to build a zImage from a kernel tree
#
# Copyright (C) 2017-2018 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT AND MAC CHECK
source common

# START TIME
START=$(date +%s)

# GATHER PARAMETERS
while [[ $# -ge 1 ]]; do
    case ${1} in
        # ARCHITECTURE TO BUILD; DEFAULTS TO ARM64
        "-a"|"--arch")
            shift && enforce_value "$@"

            ARCH=${1} ;;

        # USE CLANG FOR COMPILING THE KERNEL
        "-c"|"--clang")

            CLANG=true ;;

        # SPECIFY WHICH CLANG TOOLCHAIN TO USE
        "-ct"|"--clang-toolchain")
            shift && enforce_value "$@"

            CLANG_TOOLCHAIN_FOLDER=${1} ;;

        # DEFCONFIG TO BUILD; DEFAULTS TO FLASH_DEFCONFIG
        "-d"|"--defconfig")
            shift && enforce_value "$@"

            DEFCONFIG=${1} ;;

        # SHOW FULL COMPILATION
        "-D"|"--debug")
            VERBOSITY=2 ;;

        # SPECIFY WHICH GCC TOOLCHAIN TO USE
        "-gt"|"--gcc-toolchain")
            shift && enforce_value "$@"

            GCC_TOOLCHAIN_FOLDER=${1} ;;

        # UPLOAD IMAGE TO TRANSFER.SH
        "-u"|"--upload")
            UPLOAD=true ;;

        # SHOW WARNINGS AND ERRORS DURING COMPILATION
        "-w"|"--warnings")
            VERBOSITY=1 ;;
    esac

    shift
done

# DEFAULTS
if [[ -z ${ARCH} ]]; then
    ARCH=arm64
fi
if [[ -z ${GCC_TOOLCHAIN_FOLDER} ]]; then
    GCC_TOOLCHAIN_FOLDER=/home/ekoariffaizal/arch/bin/aarch64-cortex_a53-linux-android-
fi

# ERROR OUT IF DEFCONFIG WASN'T SUPPLIED
if [[ -z ${DEFCONFIG} ]]; then
    die "lemper_defconfig!"
fi

# SET TOOLCHAINS
GCC_TOOLCHAIN=$(find ${GCC_TOOLCHAIN_FOLDER}/bin -type f -name '*-gcc' | head -n1)
if [[ -z ${GCC_TOOLCHAIN} ]]; then
    die "GCC toolchain could not be found!"
fi
if [[ ${CLANG} ]]; then
    if [[ -z ${CLANG_TOOLCHAIN_FOLDER} ]]; then
        CLANG_TOOLCHAIN_FOLDER=/home/ekoariffaizal/arch/bin/
    fi
    CLANG_TOOLCHAIN=${CLANG_TOOLCHAIN_FOLDER}/bin/clang
    if [[ ! -f ${CLANG_TOOLCHAIN} ]]; then
        die "Clang toolchain could not be found!"
    fi
fi

# SET CCACHE
CCACHE=$(command -v ccache)

# BASIC BUILD FUNCTION
function build() {
    # SET MAKE VARIABLE
    MAKE="make ${JOBS_FLAG} O=out ARCH=${ARCH}"

    # CLEAN UP FROM LAST COMPILE
    rm -rf out && mkdir -p out

    # MAKE DEFCONFIG
    ${MAKE} "${DEFCONFIG}"

    # MAKE KERNEL
    if [[ ${CLANG} ]]; then
        PATH=${BIN_FOLDER}:${PATH} ${MAKE} CC="${CCACHE} ${CLANG_TOOLCHAIN}" \
                                           CLANG_TRIPLE=aarch64-linux-gnu- \
                                           CROSS_COMPILE="${GCC_TOOLCHAIN%gcc}" \
                                           HOSTCC="${CCACHE} ${CLANG_TOOLCHAIN}"
    else
        ${MAKE} CROSS_COMPILE="${CCACHE} ${GCC_TOOLCHAIN%gcc}"
    fi
}

# REPORT ERROR IF WE AREN'T IN A TREE WITH A MAKEFILE
if [[ ! -f Makefile ]]; then
    die "This must be run in a kernel tree!"
fi

# SHOW THE BASE VERSION WE ARE MAKING
header "BUILDING $(make kernelversion)"

# SHOW COMPILATION BASED ON FLAGS
case ${VERBOSITY} in
    "2")
        build ;;
    "1")
        build |& ag --nocolor "error:|warning" ;;
    *)
        build &> /dev/null ;;
esac

# REPORT SUCCESS
FINAL_IMAGE=$(find out -name 'Image.*-dtb')
END=$(date +%s)
if [[ -f ${FINAL_IMAGE} ]]; then
    echo "\n${GRN}BUILT IN $(format_time "${END}" "${START}")${RST}\n
${BOLD}IMAGE:${RST} ${FINAL_IMAGE}\n
${BOLD}VERSION:${RST} $(cat out/include/config/kernel.release)"
else
    die "Kernel build failed!"
fi

# UPLOAD IMAGE IF NECESSARY
if [[ ${UPLOAD} ]]; then
    echo
    curl --upload-file "${FINAL_IMAGE}" https://transfer.sh/"${IMAGE}"
fi

# ALERT OF SCRIPT END
echo "\n\a"
