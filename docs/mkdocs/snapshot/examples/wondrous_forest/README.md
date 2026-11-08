# Ceedling Wondrous Forest Project

An imagined forest environmental monitoring station that reads temperature,
humidity, light, and soil moisture from a network of sensors — raising
alerts when conditions exceed thresholds. The project exists to showcase
Ceedling's Partials feature alongside traditional mock-based testing.

This example project illustrates:

- **Partials** — testing `static`, `inline`, and `static inline` C functions
  and `static` variables that are normally inaccessible to the linker
- **Every major Partials pattern** across a range of sensor and system modules
- **Partials and mocks used together** in the same test suite
- **Carrying** — a Partial bringing along the helpers, prototypes, and
  variables its selected functions rely on

This project is test-suite only (no release build).

---

## Project Structure

```
wondrous_forest/
├── project.yml        # Ceedling configuration (note :use_partials: TRUE)
├── mixin/             # Optional add-on configuration
│   └── add_gcov.yml   # Enables gcov coverage collection and reporting
├── src/               # Source modules
│   ├── TemperatureSensor.c/.h
│   ├── HumiditySensor.c/.h
│   ├── LightSensor.c/.h
│   ├── SoilMoisture.c/.h
│   ├── AlertManager.c/.h
│   ├── EventQueue.c/.h
│   ├── ForestMonitor.c/.h
│   ├── SensorHal.c/.h
│   ├── UartDriver.c/.h
│   ├── RainGauge.c/.h
│   ├── RainTipIsr.c/.h # Defines the tip counter RainGauge.h declares extern
│   ├── ForestUnits.h   # C99 inline functions, no source file of its own
│   ├── sensors/soil/Calibration.c/.h   # Same module name as the one below
│   ├── sensors/light/Calibration.c/.h  # Told apart by directory
│   └── Types.h
└── test/              # Test files — Using Partials and traditional assertions/mocks
    ├── TestTemperatureSensor.c
    ├── TestHumiditySensor.c
    ├── TestLightSensor.c
    ├── TestSoilMoisture.c
    ├── TestAlertManager.c
    ├── TestEventQueue.c
    ├── TestForestMonitor.c
    ├── TestSensorHal.c
    ├── TestUartDriver.c
    ├── TestRainGauge.c
    └── TestCalibration.c
```

---

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
| TestCalibration.c       | `TEST_PARTIAL_PRIVATE_MODULE_AT` — two same-named modules     |
| TestRainGauge.c         | `TEST_PARTIAL_PUBLIC_MODULE` + a subtracted, stubbed function |

---

## What a Partial Carries

A Partial brings along what its selected functions rely on. `TestRainGauge.c`
selects RainGauge's public functions and subtracts one of them. Those
functions rely on code the test does not select, so the Partial carries it.
Run the test with `--verbosity=debug` to see each carried item and why.

| Carried item | Why the Partial needs it |
|---|---|
| `RainGauge_TipsToMicrometers()` | `RainGauge.h` defines this `static inline` helper, and `RainGauge_Update()` calls it |
| `extern inline` prototype of `ForestUnits_MicrometersToTenthsMm()` | `ForestUnits.h` defines the function C99 `inline`. The prototype makes the Partial hold its external definition |
| Prototype of `RainGauge_ReportStorm()` | The test subtracts this function and defines a stub. `RainGauge_Update()` calls the stub |
| Weak definition of `g_rain_tip_count` | `RainGauge.h` declares the counter `extern`. Its real definition in `RainTipIsr.c`, which the test links, takes precedence |

Each carried item keeps its original spelling. A `#line` directive ahead of
each points back to its original file and line. Coverage of the carried
helper therefore counts toward `RainGauge.h`.

---

## Running the Tests

Run all tests:

```sh
ceedling test:all
```

Run a single test file:

```sh
ceedling test:TestTemperatureSensor
ceedling test:TestForestMonitor
```

---

## Optional Mixins

### Coverage with gcov

Collect and report test coverage (requires `gcov` and `gcovr`):

```sh
ceedling gcov:all --mixin=mixin/add_gcov.yml
```
