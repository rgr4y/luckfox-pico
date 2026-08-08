# ESP-Hosted-NG host driver -> esp32_sdio.ko (ESP32 as SDIO WiFi, native wlan0).
# Built INTO the image but deliberately NOT auto-loaded (absent from
# ../insmod_ko.sh): install the image, wire the ESP to the SDIO header pins,
# then `modprobe esp32_sdio` (pulls cfg80211). See docs/esp-hosted-sdio-plan.md.
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
	@make -C host ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) KERNEL=$(ESP_KOBJ) target=sdio all
	@cp -f host/esp32_sdio.ko $(M_OUT_DIR)/
	@echo "esp_hosted: esp32_sdio.ko built (not auto-loaded)"

clean:
	@make -C host ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) KERNEL=$(ESP_KOBJ) target=sdio clean 2>/dev/null || true
