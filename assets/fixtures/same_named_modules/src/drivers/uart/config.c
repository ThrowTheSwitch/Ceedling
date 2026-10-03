#include "drivers/uart/config.h"

static int adjust(int value) { return value + 10; }

static int uart_only(void) { return 1; }

int uart_config_baud(void) { return adjust(1152) + uart_only(); }
