# Ceedling Wondrous Forest Example

Welcome to the **Wondrous Forest** example — a forest environmental monitoring
station written in embedded C that showcases Ceedling's **Partials** feature.

## What This Example Demonstrates

Ceedling Partials expose `static`, `inline`, and `static inline` C functions
and `static` variables for unit testing — something impossible under normal C
linkage rules. This project uses every major Partials pattern alongside
traditional mock-based testing so you can see how the two approaches mix.

## Directory Layout

```
src/          Source modules (sensors, alert manager, event queue, monitor)
test/         Test files — Partials-based and traditional
project.yml   Ceedling configuration (note :use_partials: TRUE)
mixin/        Optional configuration add-ons (gcov coverage)
```

## Partials Patterns Used

| Test File               | Pattern                                                       |
|-------------------------|---------------------------------------------------------------|
| TestTemperatureSensor.c | `TEST_PARTIAL_ALL_MODULE` — public + private functions        |
| TestHumiditySensor.c    | `TEST_PARTIAL_ALL_MODULE` + `PARTIAL_LOCAL_VAR()`             |
| TestLightSensor.c       | `TEST_PARTIAL_PUBLIC_MODULE` + `MOCK_PARTIAL_PRIVATE_MODULE`  |
| TestSoilMoisture.c      | `TEST_PARTIAL_ALL_MODULE` + `PARTIAL_LOCAL_VAR()`             |
| TestAlertManager.c      | `TEST_PARTIAL_ALL_MODULE` + traditional mock alongside        |
| TestEventQueue.c        | `TEST_PARTIAL_ALL_MODULE` + file-scope static access          |
| TestForestMonitor.c     | `TEST_PARTIAL_PUBLIC_MODULE` + `MOCK_PARTIAL_PRIVATE_MODULE`  |
| TestSensorHal.c         | Traditional — HAL has no private statics                      |
| TestUartDriver.c        | Traditional — UART driver has no private statics              |

## Running the Tests

```bash
ceedling test:all
```
