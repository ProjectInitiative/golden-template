#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <stdio.h>

static const char *TAG = "main";

void app_main(void) { ESP_LOGI(TAG, "Hello from my-firmware!"); }
