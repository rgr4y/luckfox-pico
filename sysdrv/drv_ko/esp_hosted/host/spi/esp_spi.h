// SPDX-License-Identifier: GPL-2.0-only
/*
 * SPDX-FileCopyrightText: 2015-2023 Espressif Systems (Shanghai) CO LTD
 *
 */

#ifndef _ESP_SPI_H_
#define _ESP_SPI_H_

#include "esp.h"

/* RV1106 (Luckfox Pico Pro Max) global GPIO numbers (gpioN base = N*32).
 * Was RPi BCM 22/27. HANDSHAKE=GPIO1_D3 pin10 (glob 59) <- C5 IO9(HANDSHAKE);
 * DATA_READY=GPIO2_B1 pin11 (glob 73) <- C5 IO2(DATA_READY). */
#define HANDSHAKE_PIN           59
#define SPI_IRQ                 gpio_to_irq(HANDSHAKE_PIN)
#define SPI_DATA_READY_PIN      73
#define SPI_DATA_READY_IRQ      gpio_to_irq(SPI_DATA_READY_PIN)
/* RESET_PIN drives the C5 EN (chip-enable, active-high). GPIO1_D2 pin9 (glob 58),
 * next to HANDSHAKE(pin10)/DATA_READY(pin11). Driver pulses it low->high at load so
 * the C5 boots AFTER the rising-edge IRQs are armed -> deterministic sync regardless
 * of load order, no manual reset. Boot-safe: pin is input(hi-Z) until requested, so
 * the C5 EN pullup keeps the chip enabled before the driver claims the line. */
#define RESET_PIN               58
#define ESP_RESET_LOW_MS        100     /* EN held low (assert reset) */
#define ESP_RESET_BOOT_MS       100     /* settle after release before continuing */
#define SPI_BUF_SIZE            1600

enum spi_flags_e {
	ESP_SPI_BUS_CLAIMED,
	ESP_SPI_BUS_SET,
	ESP_SPI_GPIO_HS_REQUESTED,
	ESP_SPI_GPIO_HS_IRQ_DONE,
	ESP_SPI_GPIO_DR_REQUESTED,
	ESP_SPI_GPIO_DR_IRQ_DONE,
	ESP_SPI_GPIO_RESET_REQUESTED,
	ESP_SPI_DATAPATH_OPEN,
};

struct esp_spi_context {
	struct esp_adapter          *adapter;
	struct spi_device           *esp_spi_dev;
	struct sk_buff_head         tx_q[MAX_PRIORITY_QUEUES];
	struct sk_buff_head         rx_q[MAX_PRIORITY_QUEUES];
	struct workqueue_struct     *spi_workqueue;
	struct work_struct          spi_work;
	struct workqueue_struct     *nw_cmd_reinit_workqueue;
	struct work_struct          nw_cmd_reinit_work;
	uint8_t                     spi_clk_mhz;
	uint8_t                     reserved[2];
	unsigned long               spi_flags;
};

enum {
	CLOSE_DATAPATH,
	OPEN_DATAPATH,
};


#endif
