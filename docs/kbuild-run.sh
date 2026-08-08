set -e
echo "=== extract pristine kernel from git into case-sensitive /build ==="
rm -rf /build && mkdir -p /build
cd /sdk
git config --global --add safe.directory /sdk
git archive HEAD sysdrv/source/kernel | tar -x -C /build
cp -v /sdk/sysdrv/source/kernel/arch/arm/configs/luckfox_rv1106_linux_defconfig \
      /build/sysdrv/source/kernel/arch/arm/configs/luckfox_rv1106_linux_defconfig
cp -v /sdk/sysdrv/source/kernel/scripts/resource_tool /build/sysdrv/source/kernel/scripts/resource_tool 2>/dev/null || true
file /build/sysdrv/source/kernel/Documentation/Kbuild
export ARCH=arm
export CROSS_COMPILE=arm-rockchip830-linux-uclibcgnueabihf-
export PATH="/sdk/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/bin:/sdk/output/out/sysdrv_out/pc:$PATH"
which mkimage
cd /build/sysdrv/source/kernel
echo "=== mrproper ==="; make mrproper >/dev/null 2>&1
echo "=== defconfig ==="; make luckfox_rv1106_linux_defconfig >/dev/null
echo "--- ZRAM in .config ---"; grep -E "CONFIG_ZRAM|CONFIG_ZSMALLOC|CONFIG_CRYPTO_ZSTD" .config
echo "=== build img ==="; make rv1106g-luckfox-pico-pro-max.img BOOT_ITS=$PWD/boot.its -j$(nproc)
echo "=== done; staging ==="
ls -la boot.img
cp -v boot.img /sdk/boot-zram.img
echo "STAGED_OK"
