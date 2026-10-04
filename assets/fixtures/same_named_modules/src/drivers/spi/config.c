#include "drivers/spi/config.h"

// Named per module -- see the uart module beside this one.
static int spi_adjust(int value) { return value * 2; }

static int spi_only(void) { return 2; }

int spi_config_clock_div(void) { return spi_adjust(8) + spi_only(); }
