compile_commands_json
=====================

## Overview

The compile_commands_json plugin creates a JSON file as expected by clang or
produced by CMake. Numerous IDE's now support this format as a way of fetching
build information about a particular file. You will find the output file in the
`<build_root>/artifacts/` directory (e.g. `artifacts/test/` for test tasks,
`artifacts/gcov/` for gcov, or `artifacts/bullseye/` for bullseye runs).

## Setup

Enable the plugin in your project.yml by adding `compile_commands_json` to the list
of enabled plugins.

``` YAML
:plugins:
  :enabled:
    - compile_commands_json
```

## Configuration

There is no additional configuration necessary to run this plugin.
