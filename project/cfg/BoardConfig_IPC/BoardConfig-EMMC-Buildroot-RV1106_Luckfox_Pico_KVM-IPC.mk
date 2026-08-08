#!/bin/bash

#################################################
# 	Board Config — Luckfox Pico KVM
#################################################
export LF_ORIGIN_BOARD_CONFIG=BoardConfig-EMMC-Buildroot-RV1106_Luckfox_Pico_KVM-IPC.mk
# Target CHIP
export RK_CHIP=rv1106

# app config
export RK_APP_TYPE=RKIPC_RV1106

# Config CMA size in environment
export RK_BOOTARGS_CMA_SIZE="66M"

# Kernel dts
export RK_KERNEL_DTS=rv1106g-luckfox-pico-kvm.dts

#################################################
#	BOOT_MEDIUM
#################################################

# Target boot medium
export RK_BOOT_MEDIUM=emmc

# Uboot defconfig fragment
export RK_UBOOT_DEFCONFIG_FRAGMENT=rk-emmc.config

# config partition in environment
# PicoKVM uses A/B system slots (no separate oem partition — oem is baked into system)
# Matches the stock PicoKVM partition layout from /proc/cmdline:
#   32K(env),512K@32K(idblock),512K(uboot_a),512K(uboot_b),256K(misc),
#   1M(security),32M(boot_a),32M(boot_b),640M(system_a),640M(system_b),5G(userdata)
export RK_PARTITION_CMD_IN_ENV="32K(env),512K@32K(idblock),512K(uboot_a),512K(uboot_b),256K(misc),1M(security),32M(boot_a),32M(boot_b),640M(system_a),640M(system_b),5G(userdata)"

# config partition's filesystem type
# system_a is the root, userdata is user-writable
export RK_PARTITION_FS_TYPE_CFG=system_a@IGNORE@ext4,system_b@IGNORE@ext4,userdata@/userdata@ext4

#################################################
#	TARGET_ROOTFS
#################################################

# Target rootfs
export LF_TARGET_ROOTFS=buildroot

# Buildroot defconfig — KVM-specific (adds VPN tools, gdb, etc)
export RK_BUILDROOT_DEFCONFIG=luckfox_pico_kvm_defconfig

#################################################
# 	Defconfig
#################################################

# Target arch
export RK_ARCH=arm

# Target Toolchain Cross Compile
export RK_TOOLCHAIN_CROSS=arm-rockchip830-linux-uclibcgnueabihf

#misc image
export RK_MISC=wipe_all-misc.img

# Uboot defconfig
export RK_UBOOT_DEFCONFIG=luckfox_rv1106_uboot_defconfig

# Kernel defconfig
export RK_KERNEL_DEFCONFIG=luckfox_rv1106_linux_defconfig

# Kernel defconfig fragment — enable TC358743 HDMI capture
export RK_KERNEL_DEFCONFIG_FRAGMENT=rv1106-kvm.config

# Config sensor IQ files (KVM uses TC358743 HDMI-to-CSI, but keep SC3336 for compat)
export RK_CAMERA_SENSOR_IQFILES="sc3336_CMK-OT2119-PC1_30IRC-F16.json"

# No IPC web backend
#export RK_APP_IPCWEB_BACKEND=y

# NO separate oem partition — merge oem content (ko's, libs, bins) into rootfs /oem/
# Setting this to anything other than "y" triggers the else branch in build.sh
# which copies oem output into the rootfs instead of building a separate oem.img
export RK_BUILD_APP_TO_OEM_PARTITION=n

# enable rockchip test
export RK_ENABLE_ROCKCHIP_TEST=y

# No WiFi chip on base KVM board (networking via ethernet + VPN)
#export RK_ENABLE_WIFI=y

#################################################
#  PRE and POST
#################################################

# specify pre.sh for delete/overlay files
export RK_PRE_BUILD_OEM_SCRIPT=luckfox-buildroot-oem-pre.sh

# specify post.sh for delete/overlay files
export RK_PRE_BUILD_USERDATA_SCRIPT=luckfox-userdata-pre.sh

# declare overlay directories
export RK_POST_OVERLAY="overlay-luckfox-config overlay-luckfox-buildroot-init overlay-luckfox-buildroot-shadow overlay-picokvm"
