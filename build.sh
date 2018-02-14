#!/bin/bash

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
#### USAGE:
#### ./buildCosmos.sh [clean]
#### [clean] - clean is optional
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
#####
### Prepared by:
### Eko arif fazial
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#

####
## platform specifics
export ARCH=arm64
export SUBARCH=arm64
TOOL_CHAIN_ARM=aarch64-cortex_a53-linux-android-

#@@@@@@@@@@@@@@@@@@@@@@ DEFINITIONS BEGIN @@@@@@@@@@@@@@@@@@@@@@@@@@@#
##### Tool-chain, you should get it yourself which tool-chain
##### you would like to use
KERNEL_TOOLCHAIN=/home/ekoariffaizal/arch/bin/$TOOL_CHAIN_ARM

## This script should be inside the kernel-code directory
KERNEL_DIR=$PWD

BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'
## should be preset in arch/arm/configs of kernel-code
KERNEL_DEFCONFIG=lemper_defconfig

## make jobs
MAKE_JOBS=$(grep -c ^processor /proc/cpuinfo)

## Give the path to the toolchain directory that you want kernel to compile with
## Not necessarily to be in the directory where kernel code is present
export CROSS_COMPILE="$(command -v ccache) $KERNEL_TOOLCHAIN"

#@@@@@@@@@@@@@@@@@@@@@@ DEFINITIONS  END  @@@@@@@@@@@@@@@@@@@@@@@@@@@#


# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it such
# as in the --default example).
# note: if this is set to -gt 0 the /etc/hosts part is not recognized ( may be a bug )
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    clean)
    CLEAN_BUILD=YES
    #shift # past argument
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done


#@@@@@@@@@@@@@@@@@ START @@@@@@@@@@@@@@@@@@@@#
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#

rm -f .version;
	echo 0 > .version;
	rm -f include/generated/compile.h

# Ask for version number
version() {
	printf "Kernel build number: ";
	read v;
  EV=EXTRAVERSION=$v;
  echo "$v" > .extraversion;
}

version2() {
	printf "ZIP Package version or name: ";
	read z;
}

## start ##


## copy Anykernel2 from /root

echo "#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#"
echo " # SCRIPT COMPILER #"
echo "#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#"
echo " "
version2;
version;
echo "***** Tool chain is set to *****"
echo "$KERNEL_TOOLCHAIN"
echo ""
echo "***** Kernel defconfig is set to *****"
echo "$KERNEL_DEFCONFIG"
 make $KERNEL_DEFCONFIG
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# Read [clean]
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
if [ "$CLEAN_BUILD" == 'YES' ]
        then echo;
        echo "***************************************************************"
        echo "***************!!!!!  BUILDING CLEAN  !!!!!********************"
        echo "***************************************************************"
        echo;
         make clean
         make mrproper
        make ARCH=$ARCH export CROSS_COMPILE="$(command -v ccache) $KERNEL_TOOLCHAIN"   $KERNEL_DEFCONFIG
fi


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# Do the JOB, make it
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
## you can tune the job number depends on the cores
   v=`cat .extraversion`;
  EV=EXTRAVERSION=-$v;
 make $EV -j$MAKE_JOBS

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
#@@@@@@@@@@@@@@@@@@ END @@@@@@@@@@@@@@@@@@@@@#


#@@@@@@@@@@@@@@@@ AnyKernel2 @@@@@@@@@@@@@@@@@@@@@@#
# Environment variables for flashable zip creation (AnyKernel2)
ANYKERNEL=$PWD/AnyKernel2;
AROMA=$ANYKERNEL/META-INF/com/google/android/aroma;

##sesuaikan lokasi boot arm/arm64 dan nama zImage
KERNELPATH=arch/arm64/boot;
ZIMAGE=Image.gz-dtb

# NOTE: Generate value for build date before creating zip in order to get accurate value
DATE=$(date +"%Y%m%d-%H%M");

# generate changelog
echo "generating changelog . . .";
git --no-pager log --pretty=oneline --abbrev-commit 1ded9a48..HEAD > $AROMA/changelog.txt

#ubah nama device masing-masing (ido)
ZIP=Lemper_kernel.zip;

# Create flashable zip
if [ -f $KERNELPATH/$ZIMAGE ]; then
echo "Create Flashable zip Anykernel2";
cp -f $KERNELPATH/$ZIMAGE $ANYKERNEL/anykernel/$ZIMAGE;
cd $ANYKERNEL/;
zip -qr9 $ZIP .;
cd ../..;

#Then doing cleanup
echo "Doing post-cleanup...";
rm -rf arch/arm/boot/dtb;
rm -rf $ANYKERNEL/anykernel/Image.gz-dtb;
rm -rf $AROMA/changelog.txt;
echo "Done.";

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

echo "#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#"
echo "                                        "
echo "     KERNEL BUILD IS SUCCESSFUL         "
echo "                                        "
echo " $ZIP                 "
echo "                                        "
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
echo "#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#"
else
echo "#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#"
echo "                                        "
echo "     ERROR !!! ERROR !!! ERROR !!!      "
echo "                                        "
echo "          DON'T GIVE UP @_@             "
echo "                                        "
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
echo "#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#"
fi
exit
