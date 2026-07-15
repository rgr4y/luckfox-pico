# Reproducible ESP-Hosted-NG C5 slave build — no local ESP-IDF install.
# C5 needs IDF >= 5.5. Pinned image for determinism.
#   docker build -t esp-c5-slave .
#   docker run --rm -v "$PWD/network_adapter:/project" -w /project esp-c5-slave \
#     bash -lc 'idf.py set-target esp32c5 && idf.py build'
#   -> network_adapter/build/network_adapter.bin
FROM espressif/idf:v5.5.1
ENV IDF_TARGET=esp32c5
WORKDIR /project
