#!/bin/bash
#
# Compile script for uvite Kernel
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0 # builtin bash timer
ZIPNAME="HuP-K$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/neutron"
TU="$(pwd)/tc"
EY="$(pwd)"
AK3_DIR="$(pwd)/android/AnyKernel3"
DEFCONFIG="vendor/spes-perf_defconfig"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}.zip"
fi

export PATH="$TC_DIR/bin:$PATH"
export KBUILD_BUILD_USER=nobody
export KBUILD_BUILD_HOST=android-build

if ! [ -d "$TC_DIR" ]; then
	echo "Neutron clang not found! Cloning to $TC_DIR..."
	if ! mkdir -p tc
		cd "$TU"
		mkdir -p neutron && wget https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/10032024/neutron-clang-10032024.tar.zst 
		tar -xvf neutron-clang-10032024.tar.zst -C "$TC_DIR"
		rm -rf neutron-clang-10032024.tar.zst
		cd "$EY"
		"$TC_DIR"; then
		echo "Cloning failed! Aborting..." && rm -rf "$TC_DIR"
		exit 1
	fi
fi

# KSU
rm -rf KernelSU && curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main && cd KernelSU && git revert --no-edit 898e9d4 && cd ../

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-rf" || $1 = "--regen-full" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG
	cp out/.config arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated full defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 LLVM=1 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM=1 Image.gz dtbo.img 2> >(tee log.txt >&2) || exit $?

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q https://github.com/JohanKepler/AnyKernel3 -b HuP-Ksu; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
	cp $kernel $dtbo AnyKernel3
	rm -rf out/arch/arm64/boot
	cd AnyKernel3
	git checkout master &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi

