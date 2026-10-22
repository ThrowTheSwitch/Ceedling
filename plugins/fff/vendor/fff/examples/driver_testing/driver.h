/* =========================================================================
    Vendored third-party source, under its own copyright and license.
    Not Ceedling code, and carries no Ceedling copyright banner.

    Fake Function Framework ⏩️ https://github.com/meekrosoft/fff
    License ⏩️ plugins/fff/vendor/fff/LICENSE
========================================================================= */





#ifndef DRIVER
#define DRIVER

#include <stdint.h>

void driver_write(uint8_t val);
uint8_t driver_read();
void driver_init_device();

#endif /*include guard*/
