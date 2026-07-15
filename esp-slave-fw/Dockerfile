# ESP-Hosted-NG does NOT build against stock ESP-IDF. Its esp_driver/setup.sh:
#   1. pins esp-idf to a specific commit (see .env: v5.5.1 @ fcae328)
#   2. applies lib/rom.patch  (comments out sta_rx_eapol / sta_auth_shared ROM syms)
#   3. REPLACES components/esp_wifi/lib/* with NG's patched WiFi blobs — these are
#      what define esp_wifi_send_auth_internal / ieee80211_add_node / etc. that the
#      slave's cmd.c links against. Stock v5.5.1 libs lack them -> link fails.
# This image reproduces that against the base IDF image, so `idf.py build` links.
FROM espressif/idf:v5.5.1

# Keep in sync with .env (IDF_COMMIT)
ARG IDF_COMMIT=fcae32885b0296b32044cb99ecbdc50d98dddb83

# NG's patched WiFi libs + rom.patch (vendored alongside this Dockerfile)
COPY lib /ng-lib

RUN set -eux; \
    cd "$IDF_PATH"; \
    git config --global --add safe.directory "$IDF_PATH"; \
    git fetch --depth 200 origin v5.5.1 || true; \
    git checkout -f "$IDF_COMMIT"; \
    git submodule update --init --recursive --depth 1; \
    echo ">> applying NG rom.patch"; \
    git apply /ng-lib/rom.patch; \
    echo ">> swapping in NG patched esp_wifi libs"; \
    rm -rf components/esp_wifi/lib/*; \
    cp -r /ng-lib/* components/esp_wifi/lib/; \
    rm -f components/esp_wifi/lib/rom.patch; \
    echo ">> re-running install for esp32c5 (tools for pinned commit)"; \
    ./install.sh esp32c5

WORKDIR /project
