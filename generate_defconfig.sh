export ARCH=arm64
export SUBARCH=arm64
make lemper_defconfig
cp .config arch/arm64/configs/lemper_defconfig
