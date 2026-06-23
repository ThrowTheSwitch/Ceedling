# `wondrous_forest`

An imagined forest environmental monitoring station that reads temperature,
humidity, light, and soil moisture — raising alerts when conditions exceed
thresholds. Test suite only.

See the [project README](../../snapshot/examples/wondrous_forest/README.md)
for full details. The README is linked here for convenience but is also
exported with the example project.

## Exporting

```shell
ceedling example wondrous_forest [destination]
```

## About

`wondrous_forest` demonstrates Ceedling's [Partials](../../testing-guide/partials/index.md)
feature — the ability to test `static`, `inline`, and `static inline` C
functions and `static` variables that are otherwise inaccessible under normal
C linkage rules. Every major Partials pattern appears somewhere in the project,
alongside traditional mock-based tests.

After exporting, run `ceedling test:all` from the project root to execute the
full test suite.

## Partials patterns

Each sensor module uses a different Partials pattern, making the project a
comprehensive reference:

| Test file               | Pattern                                                      |
|-------------------------|--------------------------------------------------------------|
| TestTemperatureSensor.c | `TEST_PARTIAL_ALL_MODULE` — public + private functions       |
| TestHumiditySensor.c    | `TEST_PARTIAL_ALL_MODULE` + `PARTIAL_LOCAL_VAR()`            |
| TestLightSensor.c       | `TEST_PARTIAL_PUBLIC_MODULE` + `MOCK_PARTIAL_PRIVATE_MODULE` |
| TestSoilMoisture.c      | `TEST_PARTIAL_ALL_MODULE` + `PARTIAL_LOCAL_VAR()`            |
| TestAlertManager.c      | `TEST_PARTIAL_ALL_MODULE` + traditional mock alongside       |
| TestEventQueue.c        | `TEST_PARTIAL_ALL_MODULE` + file-scope static access         |
| TestForestMonitor.c     | `TEST_PARTIAL_PUBLIC_MODULE` + `MOCK_PARTIAL_PRIVATE_MODULE` |
| TestSensorHal.c         | Traditional — HAL has no private statics                     |
| TestUartDriver.c        | Traditional — UART driver has no private statics             |

<br/><br/>
