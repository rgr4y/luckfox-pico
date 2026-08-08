# ESP-Hosted-NG host driver -> esp32_spi.ko (ESP32-C5 as SPI WiFi, native wlan0).
# Built INTO the image but deliberately NOT auto-loaded (absent from
# ../insmod_ko.sh): install the image, wire the C5 to spi0 (see &spi0 in the
# board dts), then `modprobe esp32_spi` (pulls cfg80211 -> wlan0). Add
# resetpin=<gpio> if you wired a reset line to the C5 EN. See
# docs/esp-hosted-spi-plan.md.
ifeq ($(SYSDRV_PARAM), )
	SYSDRV_PARAM:=../../Makefile.param
	include $(SYSDRV_PARAM)
endif

ifneq ($(SYSDRV_KERNEL_OBJS_OUTPUT_DIR),)
ESP_KOBJ=$(SYSDRV_KERNEL_OBJS_OUTPUT_DIR)
else
ESP_KOBJ=$(KERNEL_DIR)
endif

all:
	@make -C host ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) KERNEL=$(ESP_KOBJ) target=spi all
	@cp -f host/esp32_spi.ko $(M_OUT_DIR)/
	@echo "esp_hosted: esp32_spi.ko built (not auto-loaded)"

clean:
	@make -C host ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) KERNEL=$(ESP_KOBJ) target=spi clean 2>/dev/null || true
