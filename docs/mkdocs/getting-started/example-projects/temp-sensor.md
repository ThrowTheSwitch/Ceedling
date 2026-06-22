# `temp_sensor`

:material-memory: An imagined temperature sensor testing project containing
assertions, mocks, and code techniques representative of embedded development.
Test suite only.

## Exporting

```shell
ceedling example temp_sensor [destination]
```

## About

`temp_sensor` simulates firmware for a temperature sensor peripheral. It
demonstrates how to structure a C test suite for embedded code, including:

- Unity assertions for validating values and behaviors
- CMock-generated mocks for hardware abstraction layer dependencies
- Code organization patterns common in embedded development

After exporting, run `ceedling test:all` from the project root to execute the
full test suite.

<br/><br/>
