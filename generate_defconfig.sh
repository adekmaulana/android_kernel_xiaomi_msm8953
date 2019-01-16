export ARCH=arm64
export SUBARCH=arm64
make sg_defconfig
cp .config arch/arm64/configs/sg_defconfig
