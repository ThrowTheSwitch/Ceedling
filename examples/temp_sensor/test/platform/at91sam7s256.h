/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/*
 * Platform standin for AT91SAM7S256 peripheral registers.
 *
 * In the embedded build this header is provided by Atmel/Microchip's device
 * SDK and maps AT91C_BASE_* to the real hardware addresses. Here it maps
 * those same macros to ordinary C structs allocated in normal memory, so
 * the hardware-layer source files can compile and run on any host machine.
 *
 * Project configuration must add test/platform to the support include path
 * so that this file is found during test builds (see project.yml :paths:
 * :support:). Source files that reference peripheral symbols include this
 * header directly, exactly as they would include the real vendor header.
 *
 * Bit-mask constant values are taken from the AT91SAM7S256 datasheet.
 */

#ifndef AT91SAM7S256_H
#define AT91SAM7S256_H

#include "Types.h"

/* -------------------------------------------------------------------------
 * Peripheral register-block struct types
 * ------------------------------------------------------------------------- */

/* ADC - Analog-to-Digital Converter */
typedef struct
{
  uint32 ADC_CR;    /* Control Register          (offset 0x00) */
  uint32 ADC_MR;    /* Mode Register             (offset 0x04) */
  uint32 ADC_CHER;  /* Channel Enable Register   (offset 0x10) */
  uint32 ADC_SR;    /* Status Register           (offset 0x1C) */
  uint32 ADC_CDR4;  /* Channel Data Register 4   (offset 0x40) */
} AT91S_ADC;

/* TC - Timer Counter channel 0 */
typedef struct
{
  uint32 TC_CCR;    /* Clock Control Register    (offset 0x00) */
  uint32 TC_CMR;    /* Channel Mode Register     (offset 0x04) */
  uint32 TC_RC;     /* Register C                (offset 0x1C) */
  uint32 TC_SR;     /* Status Register           (offset 0x20) */
  uint32 TC_IER;    /* Interrupt Enable Register (offset 0x24) */
  uint32 TC_IDR;    /* Interrupt Disable Register(offset 0x28) */
} AT91S_TC;

/* US - USART */
typedef struct
{
  uint32 US_CR;     /* Control Register               (offset 0x00) */
  uint32 US_MR;     /* Mode Register                  (offset 0x04) */
  uint32 US_IDR;    /* Interrupt Disable Register     (offset 0x0C) */
  uint32 US_CSR;    /* Channel Status Register        (offset 0x14) */
  uint32 US_THR;    /* Transmit Holding Register      (offset 0x1C) */
  uint32 US_BRGR;   /* Baud Rate Generator Register   (offset 0x20) */
} AT91S_US;

/* PIO - Parallel I/O Controller */
typedef struct
{
  uint32 PIO_ASR;   /* Peripheral A Select Register   (offset 0x70) */
  uint32 PIO_BSR;   /* Peripheral B Select Register   (offset 0x74) */
  uint32 PIO_PDR;   /* Peripheral Disable Register    (offset 0x04) */
} AT91S_PIO;

/* PMC - Power Management Controller */
typedef struct
{
  uint32 PMC_PCER;  /* Peripheral Clock Enable Register (offset 0x10) */
} AT91S_PMC;

/* AIC - Advanced Interrupt Controller */
typedef struct
{
  uint32 AIC_IDCR;    /* Interrupt Disable Command Register (offset 0x124) */
  uint32 AIC_IECR;    /* Interrupt Enable Command Register  (offset 0x120) */
  uint32 AIC_ICCR;    /* Interrupt Clear Command Register   (offset 0x128) */
  uint32 AIC_SVR[32]; /* Source Vector Registers  (indexed by peripheral ID) */
  uint32 AIC_SMR[32]; /* Source Mode Registers    (indexed by peripheral ID) */
} AT91S_AIC;


/* -------------------------------------------------------------------------
 * Standin instance declarations (defined in at91sam7s256.c)
 * ------------------------------------------------------------------------- */

extern AT91S_ADC  AdcStandin;
extern AT91S_TC   TimerStandin;
extern AT91S_US   UsartStandin;
extern AT91S_PIO  PioAStandin;
extern AT91S_PIO  PioBStandin;
extern AT91S_PMC  PmcStandin;
extern AT91S_AIC  AicStandin;


/* -------------------------------------------------------------------------
 * Base-address macros — redirect production register accesses to standins
 * ------------------------------------------------------------------------- */

#define AT91C_BASE_ADC   (&AdcStandin)
#define AT91C_BASE_TC0   (&TimerStandin)
#define AT91C_BASE_US0   (&UsartStandin)
#define AT91C_BASE_PIOA  (&PioAStandin)
#define AT91C_BASE_PIOB  (&PioBStandin)
#define AT91C_BASE_PMC   (&PmcStandin)
#define AT91C_BASE_AIC   (&AicStandin)


/* -------------------------------------------------------------------------
 * ADC bit-mask constants (AT91SAM7S256 datasheet section 28)
 * ------------------------------------------------------------------------- */

#define AT91C_ADC_SWRST   (0x1u << 0)   /* Software Reset                */
#define AT91C_ADC_START   (0x1u << 1)   /* Start Conversion              */
#define AT91C_ADC_EOC4    (0x1u << 4)   /* End of Conversion — Channel 4 */


/* -------------------------------------------------------------------------
 * USART bit-mask constants (AT91SAM7S256 datasheet section 30)
 * ------------------------------------------------------------------------- */

/* US_CR — Control Register */
#define AT91C_US_RSTRX    (0x1u << 2)   /* Reset Receiver                */
#define AT91C_US_RSTTX    (0x1u << 3)   /* Reset Transmitter             */
#define AT91C_US_RXDIS    (0x1u << 5)   /* Receiver Disable              */
#define AT91C_US_TXEN     (0x1u << 6)   /* Transmitter Enable            */
#define AT91C_US_TXDIS    (0x1u << 7)   /* Transmitter Disable           */

/* US_MR — Mode Register fields */
#define AT91C_US_USMODE_NORMAL  (0x0u)         /* Normal USART mode       */
#define AT91C_US_CLKS_CLOCK     (0x0u << 4)    /* Master clock source     */
#define AT91C_US_CHRL_8_BITS    (0x3u << 6)    /* 8-bit character length  */
#define AT91C_US_PAR_NONE       (0x4u << 9)    /* No parity               */
#define AT91C_US_NBSTOP_1_BIT   (0x0u << 12)   /* 1 stop bit              */

/* US_CSR — Channel Status Register */
#define AT91C_US_TXRDY    (0x1u << 1)   /* Transmitter Ready             */


/* -------------------------------------------------------------------------
 * Timer Counter bit-mask constants (AT91SAM7S256 datasheet section 24)
 * ------------------------------------------------------------------------- */

/* TC_CCR — Clock Control Register */
#define AT91C_TC_CLKEN    (0x1u << 0)   /* Clock Enable                  */
#define AT91C_TC_CLKDIS   (0x1u << 1)   /* Clock Disable                 */
#define AT91C_TC_SWTRG    (0x1u << 2)   /* Software Trigger              */

/* TC_SR — Status Register */
#define AT91C_TC_CPCS     (0x1u << 4)   /* RC Compare Status             */


/* -------------------------------------------------------------------------
 * Peripheral ID constants (AT91SAM7S256 datasheet section 9)
 * ------------------------------------------------------------------------- */

#define AT91C_ID_TC0      12            /* Timer Counter 0 peripheral ID */


/* -------------------------------------------------------------------------
 * Project-specific pin and clock constants (not in the vendor header;
 * defined here so source files need only one platform include)
 * ------------------------------------------------------------------------- */

/* PMC_PCER bit masks for Timer_EnablePeripheralClocks() */
#define TIMER0_CLOCK_ENABLE   (0x1u << 12)  /* 1 << AT91C_ID_TC0          */
#define PIOB_CLOCK_ENABLE     (0x1u << 3)   /* 1 << AT91C_ID_PIOB (ID=3)  */

/* USART0 peripheral clock: used as a shift amount, not a mask */
#define USART0_CLOCK_ENABLE   6             /* AT91C_ID_US0               */

/* PIO pin masks */
#define USART0_TX_PIN         (0x1u << 10)  /* PA10 = USART0 TXD          */
#define TIOA0_PIN_MASK        (0x1u << 0)   /* PB0  = TIOA0 output        */

#endif /* AT91SAM7S256_H */
