# ESP-Hosted-NG C5 slave firmware — just `make`.
# Build runs in Docker (espressif/idf:v5.5.1), no local ESP-IDF needed.
# Flash/monitor run on the HOST (USB serial passthrough into Docker is painful
# on macOS), so they need esptool + pyserial locally: `pip install esptool pyserial`.
#
#   make            build -> network_adapter/build/network_adapter.bin
#   make flash PORT=/dev/cu.usbmodem*       flash over USB (download mode: BOOT+RST)
#                                           (macOS: cu.usbmodem* — NOT tty.*; Linux: /dev/ttyACM0)
#   make monitor PORT=...                   serial monitor @115200
#   make menuconfig                         tweak transport/config
#   make clean | make shell | make bin | make help

TARGET ?= esp32c5
PORT   ?= /dev/ttyACM0
IMG    ?= esp-c5-slave
PROJ   := network_adapter
DRUN    = docker run --rm -v "$(CURDIR)/$(PROJ):/project" -w /project $(IMG)
DRUNIT  = docker run --rm -it -v "$(CURDIR)/$(PROJ):/project" -w /project $(IMG)

.PHONY: all build image menuconfig clean distclean flash monitor shell bin help

all: build

image:
	@echo ">> building $(IMG) image (first run pulls espressif/idf:v5.5.1, ~few GB — not hung)"
	docker build -t $(IMG) .

build: image
	$(DRUN) bash -lc 'idf.py set-target $(TARGET) && idf.py build'
	@echo ">> $(PROJ)/build/network_adapter.bin"

menuconfig: image
	$(DRUNIT) bash -lc 'idf.py set-target $(TARGET) && idf.py menuconfig'

clean: image
	@$(DRUN) bash -lc 'idf.py fullclean' || true

distclean:
	rm -rf $(PROJ)/build $(PROJ)/sdkconfig $(PROJ)/managed_components $(PROJ)/dependencies.lock

# Drop into the IDF container (idf.py, esptool, etc. on PATH)
shell: image
	$(DRUNIT) bash -l

# --- host-side (needs local esptool/pyserial) ---
flash:
	cd $(PROJ)/build && esptool.py --chip $(TARGET) -p $(PORT) -b 460800 write_flash @flash_args

monitor:
	python3 -m serial.tools.miniterm $(PORT) 115200

bin:
	@ls -la $(PROJ)/build/network_adapter.bin 2>/dev/null || echo "not built — run: make"

help:
	@echo "make [build] | flash PORT=... | monitor PORT=... | menuconfig | clean | distclean | shell | bin"
	@echo "vars: TARGET=$(TARGET) PORT=$(PORT) IMG=$(IMG)"
