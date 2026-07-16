# ESP-Hosted-NG C5 slave firmware — just `make`. LOUD by design: every step
# announces itself so a long docker pull / idf build never *looks* dead.
# Build runs in Docker (espressif/idf:v5.5.1), no local ESP-IDF needed.
# Flash/monitor run on the HOST: `pip install esptool pyserial`.
#
#   make            build -> network_adapter/build/network_adapter.bin
#   make flash PORT=/dev/cu.usbmodem*       flash over USB (download mode: BOOT+RST)
#                                           (macOS: cu.usbmodem* — NOT tty.*; Linux: /dev/ttyACM0)
#   make monitor PORT=...                   serial monitor @115200
#   make menuconfig | clean | distclean | shell | bin | help

TARGET ?= esp32c5
PORT   ?= /dev/ttyACM0
IMG    ?= esp-c5-slave
PROJ   := network_adapter
DRUN    = docker run --rm -v "$(CURDIR)/$(PROJ):/project" -w /project $(IMG)
DRUNIT  = docker run --rm -it -v "$(CURDIR)/$(PROJ):/project" -w /project $(IMG)

# banner helper
define say
	@printf '\n\033[1;36m▶ %s\033[0m\n' "$(1)"
endef

.PHONY: all build image menuconfig clean distclean flash monitor shell bin help

all: build

image:
	$(call say,STEP 1/2 · docker image $(IMG))
	@echo '   first run PULLS espressif/idf:v5.5.1 (~a few GB) — watch the layer bars.'
	@echo '   NOT hung. cached after this. go get coffee.'
	@docker pull espressif/idf:v5.5.1
	@echo '   → building image layer...'
	docker build -t $(IMG) .
	@printf '\033[1;32m✓ image ready: %s\033[0m\n' "$(IMG)"

build: image
	$(call say,STEP 2/2 · idf.py set-target $(TARGET) && build  (live output below))
	@echo '   ───────────────────────────────────────────────'
	@$(DRUN) bash -lc 'idf.py set-target $(TARGET) && idf.py build'
	@echo '   ───────────────────────────────────────────────'
	@printf '\033[1;32m✓ BUILD OK\033[0m → %s\n' "$(PROJ)/build/network_adapter.bin"
	@ls -la $(PROJ)/build/network_adapter.bin
	@echo '   next: make flash PORT=/dev/cu.usbmodem*   (board in download mode: hold BOOT, tap RST)'

menuconfig: image
	$(call say,menuconfig  (arrows/enter; q to save+quit))
	$(DRUNIT) bash -lc 'idf.py set-target $(TARGET) && idf.py menuconfig'

clean: image
	$(call say,idf.py fullclean)
	@$(DRUN) bash -lc 'idf.py fullclean' || true
	@printf '\033[1;32m✓ cleaned\033[0m\n'

distclean:
	$(call say,wiping build/ sdkconfig managed_components)
	rm -rf $(PROJ)/build $(PROJ)/sdkconfig $(PROJ)/managed_components $(PROJ)/dependencies.lock
	@printf '\033[1;32m✓ distcleaned\033[0m\n'

shell: image
	$(call say,IDF container shell  (idf.py, esptool on PATH; ctrl-d to exit))
	$(DRUNIT) bash -l

# --- host-side (needs local esptool/pyserial) ---
flash:
	$(call say,flashing $(TARGET) via $(PORT)  (board must be in download mode: BOOT+RST))
	cd $(PROJ)/build && esptool.py --chip $(TARGET) -p $(PORT) -b 460800 write_flash @flash_args
	@printf '\033[1;32m✓ flashed — tap RST to run\033[0m\n'

monitor:
	$(call say,serial monitor $(PORT) @115200  (ctrl-] to quit))
	python3 -m serial.tools.miniterm $(PORT) 115200

bin:
	@ls -la $(PROJ)/build/network_adapter.bin 2>/dev/null \
	  && printf '\033[1;32m✓ built\033[0m\n' \
	  || echo 'not built yet — run: make'

help:
	@echo 'make [build] | flash PORT=... | monitor PORT=... | menuconfig | clean | distclean | shell | bin'
	@echo "vars: TARGET=$(TARGET) PORT=$(PORT) IMG=$(IMG)"
