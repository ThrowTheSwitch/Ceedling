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
    └── TestUartDriver.c
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
| TestCalibration.c       | `TEST_PARTIAL_PRIVATE_MODULE_AT` — two same-named modules      |

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
