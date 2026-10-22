/* =========================================================================
    Vendored third-party source, under its own copyright and license.
    Not Ceedling code, and carries no Ceedling copyright banner.

    Fake Function Framework ⏩️ https://github.com/meekrosoft/fff
    License ⏩️ plugins/fff/vendor/fff/LICENSE
========================================================================= */




#ifndef UI_H_
#define UI_H_

typedef void (*button_cbk_t)(void);

void UI_init();
unsigned int UI_get_missed_irqs();
void UI_button_irq_handler();
void UI_register_button_cbk(button_cbk_t cbk);
void UI_write_line(char *line);

#endif /* UI_H_ */
