/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */




/*
 * DISPLAY.h
 *
 *  Created on: Dec 17, 2010
 *      Author: mlong
 */

#ifndef DISPLAY_H_
#define DISPLAY_H_

void DISPLAY_init();
void DISPLAY_clear();
unsigned int DISPLAY_get_line_capacity();
unsigned int DISPLAY_get_line_insert_index();
void DISPLAY_output(char * message);

#endif /* DISPLAY_H_ */
