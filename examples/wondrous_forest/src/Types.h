/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef TYPES_H
#define TYPES_H

#include <stdint.h>
#include <stdbool.h>

typedef uint8_t  uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef int8_t   int8;
typedef int16_t  int16;
typedef int32_t  int32;

#ifndef NULL
#define NULL ((void*)0)
#endif

#define PRIVATE        static
#define PRIVATE_INLINE static inline

#define ADC_MAX_COUNTS        (4095u)
#define ADC_VREF_MV           (3300u)

#define TEMP_CELSIUS_MIN      (-40)
#define TEMP_CELSIUS_MAX      (85)
#define HUMIDITY_PERCENT_MIN  (0u)
#define HUMIDITY_PERCENT_MAX  (100u)
#define SOIL_MOISTURE_MIN     (0u)
#define SOIL_MOISTURE_MAX     (100u)

typedef enum
{
    ALERT_SEVERITY_NONE     = 0,
    ALERT_SEVERITY_LOW      = 1,
    ALERT_SEVERITY_MEDIUM   = 2,
    ALERT_SEVERITY_HIGH     = 3,
    ALERT_SEVERITY_CRITICAL = 4
} AlertSeverity_t;

typedef enum
{
    SENSOR_CHANNEL_TEMP     = 0,
    SENSOR_CHANNEL_HUMIDITY = 1,
    SENSOR_CHANNEL_LIGHT    = 2,
    SENSOR_CHANNEL_SOIL     = 3,
    SENSOR_CHANNEL_COUNT    = 4
} SensorChannel_t;

typedef enum
{
    EVENT_NONE            = 0,
    EVENT_TEMP_HIGH       = 1,
    EVENT_TEMP_LOW        = 2,
    EVENT_HUMIDITY_HIGH   = 3,
    EVENT_HUMIDITY_LOW    = 4,
    EVENT_LIGHT_CHANGE    = 5,
    EVENT_SOIL_DRY        = 6,
    EVENT_ALERT_TRIGGERED = 7
} EventType_t;

typedef struct
{
    EventType_t type;
    uint32      timestamp_ms;
    int32       value;
} ForestEvent_t;

typedef enum
{
    MONITOR_STATE_IDLE       = 0,
    MONITOR_STATE_SAMPLING   = 1,
    MONITOR_STATE_EVALUATING = 2,
    MONITOR_STATE_ALERTING   = 3,
    MONITOR_STATE_REPORTING  = 4
} MonitorState_t;

#endif /* TYPES_H */
