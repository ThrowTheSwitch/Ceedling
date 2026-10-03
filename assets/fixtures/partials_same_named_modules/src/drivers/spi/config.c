#include "drivers/spi/config.h"

static int adjust(int value) { return value * 2; }

static int spi_only(void) { return 2; }

int spi_config_clock_div(void) { return adjust(8) + spi_only(); }
