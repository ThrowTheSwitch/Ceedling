/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "SensorHal.h"

/* In test builds, substitute static arrays for hardware register addresses.
 * This prevents segfaults on host systems and lets TestSensorHal.c call the
 * public API with deterministic (zero-initialized) register state. */
#ifdef TEST
static uint32 s_adc_status[SENSOR_CHANNEL_COUNT] = {0u, 0u, 0u, 0u};
static uint16 s_adc_data[SENSOR_CHANNEL_COUNT]   = {0u, 0u, 0u, 0u};
static uint32 s_adc_ctrl[SENSOR_CHANNEL_COUNT]   = {0u, 0u, 0u, 0u};
static uint32 s_sys_tick                         = 0u;

#define ADC_STATUS_REG(ch)  s_adc_status[(uint8)(ch)]
#define ADC_DATA_REG(ch)    s_adc_data[(uint8)(ch)]
#define ADC_CTRL_REG(ch)    s_adc_ctrl[(uint8)(ch)]
#define SYS_TICK_REG        s_sys_tick
#else
#define ADC_BASE_ADDR       (0x40012000UL)
#define ADC_STATUS_REG(ch)  (*((volatile uint32*)(ADC_BASE_ADDR + 0x00u + (uint32)(ch) * 0x10u)))
#define ADC_DATA_REG(ch)    (*((volatile uint16*)(ADC_BASE_ADDR + 0x04u + (uint32)(ch) * 0x10u)))
#define ADC_CTRL_REG(ch)    (*((volatile uint32*)(ADC_BASE_ADDR + 0x08u + (uint32)(ch) * 0x10u)))
#define SYS_TICK_REG        (*((volatile uint32*)(0xE000E018UL)))
#endif

#define ADC_STATUS_READY_BIT (1u << 0)
#define ADC_CTRL_START_BIT   (1u << 0)

void SensorHal_Init(void)
{
    uint8 ch;
    for (ch = 0u; ch < (uint8)SENSOR_CHANNEL_COUNT; ch++)
    {
        ADC_CTRL_REG(ch) = 0u;
    }
}

uint16 SensorHal_ReadChannel(SensorChannel_t channel)
{
    return (uint16)(ADC_DATA_REG(channel) & (uint16)ADC_MAX_COUNTS);
}

bool SensorHal_IsChannelReady(SensorChannel_t channel)
{
    return (ADC_STATUS_REG(channel) & ADC_STATUS_READY_BIT) != 0u;
}

void SensorHal_StartConversion(SensorChannel_t channel)
{
    ADC_CTRL_REG(channel) |= ADC_CTRL_START_BIT;
}

uint32 SensorHal_GetTimestampMs(void)
{
    return SYS_TICK_REG;
}
