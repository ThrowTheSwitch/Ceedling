/* =========================================================================
    Vendored third-party source, under its own copyright and license.
    Not Ceedling code, and carries no Ceedling copyright banner.

    Fake Function Framework ⏩️ https://github.com/meekrosoft/fff
    License ⏩️ plugins/fff/vendor/fff/LICENSE
========================================================================= */




/*
 * DISPLAY.h
 *
 *  Created on: Dec 17, 2010
 *      Author: mlong
 */

#ifndef SYSTEM_H_
#define SYSTEM_H_

typedef void (*irq_func_t)(void);

#define IRQ_GPIO_0 0x70
#define IRQ_GPIO_1 0x71
#define IRQ_GPIO_2 0x72
#define IRQ_GPIO_3 0x73


void SYSTEM_register_irq(irq_func_t, unsigned int irq);

#endif /* SYSTEM_H_ */
