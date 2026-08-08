// SPDX-License-Identifier: GPL-2.0-only
/*
 * SPDX-FileCopyrightText: 2015-2023 Espressif Systems (Shanghai) CO LTD
 *
 */

#ifndef _ESP_SPI_H_
#define _ESP_SPI_H_

#include "esp.h"

/* RV1106 Luckfox Pico Pro Max: HS on header pin 19 = GPIO1_D0 = 56,
 * DR on header pin 20 = GPIO1_D1 = 57 (Luckfox gpio# = bank*32 + group*8 + X).
 * Both are host inputs w/ IRQ; ESP (C5 IO9/IO2) drives them. */
#define HANDSHAKE_PIN           56
#define SPI_IRQ                 gpio_to_irq(HANDSHAKE_PIN)
#define SPI_DATA_READY_PIN      57
#define SPI_DATA_READY_IRQ      gpio_to_irq(SPI_DATA_READY_PIN)
#define SPI_BUF_SIZE            1600

enum spi_flags_e {
	ESP_SPI_BUS_CLAIMED,
	ESP_SPI_BUS_SET,
	ESP_SPI_GPIO_HS_REQUESTED,
	ESP_SPI_GPIO_HS_IRQ_DONE,
	ESP_SPI_GPIO_DR_REQUESTED,
	ESP_SPI_GPIO_DR_IRQ_DONE,
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
