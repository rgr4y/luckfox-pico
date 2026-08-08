#!/bin/sh
# PicoKVM RkLunch — trimmed for the Pico Pro Max / KVM image.
#
# Removed vendor cruft (Rob):
#   - post_chk()     : launched kvm_app + camera/rkipc + SDIO-wifi insmod.
#                      kvm_app now starts from /etc/init.d/S99kvmapp (with the
#                      LD_LIBRARY_PATH=/oem/usr/lib the native helpers need).
#                      Was already neutered (#post_chk &) since 2026-07-14.
#   - network_init() : redundant with /etc/network/interfaces via S40network.
#   - check_linker() : dead code, never called.
# All that remains is running /oem/usr/etc/init.d/* and a few sysctls.

rcS() {
	for i in /oem/usr/etc/init.d/S??*; do
		# Ignore dangling symlinks / empty glob.
		[ ! -f "$i" ] && continue

		case "$i" in
		*.sh)
			# Source shell script for speed.
			(
				trap - INT QUIT TSTP
				set start
				. "$i"
			)
			;;
		*)
			# No sh extension, so fork subprocess.
			"$i" start
			;;
		esac
	done
}

rcS

ulimit -c unlimited
echo "/data/core-%p-%e" >/proc/sys/kernel/core_pattern
echo 1 >/proc/sys/vm/overcommit_memory
