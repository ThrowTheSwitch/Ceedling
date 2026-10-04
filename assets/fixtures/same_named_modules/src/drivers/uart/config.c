#include "drivers/uart/config.h"

// Named per module rather than shared. Partials expose a module's private functions so
// a test can call them, so two modules Partialized privately in one test cannot both
// define a function of the same name.
static int uart_adjust(int value) { return value + 10; }

static int uart_only(void) { return 1; }

int uart_config_baud(void) { return uart_adjust(1152) + uart_only(); }
