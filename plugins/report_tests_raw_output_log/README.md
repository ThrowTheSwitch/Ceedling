# Ceedling Plugin: Raw Test Output Logs

Capture extra console output — typically `printf()`-style statements — from 
test cases to log files.

# Plugin Overview

This plugin gathers and filters console output from test executables into log 
files. Though not required, it is usually used in addition to the 
`report_tests_*_stdout` plugins that gather and format test results for display
at the console.

Debugging in unit tested code is often accomplished with simple `printf()`-
style calls to dump information to the console. This plugin's log files can be 
helpful in supporting debugging efforts or quality validation.

## Test executable output

Ceedling and Unity cooperate to extract console statements from test executable
runs. Unity-based test executables print test case pass/fail status messages
and test case accounting to the console ($stdout).

Ceedling and various reporting plugins gather all this, including unrecognized 
output, to format it and present summaries at the console.

This plugin captures the unrecognized output to log files.

## Log files

Log files are only created if test executables produce console output apart from
expected Unity test results as described above. Log files are named for the
respective test executables.

Builds are differentiated by build context — `test`, `release`, or
plugin-modified build (e.g. `gcov`). Log files are written to `<build
root>/artifacts/<context>/<test file>.raw.log`.

# Setup

Enable the plugin in your Ceedling project:

``` YAML
:plugins:
  :enabled:
    - report_tests_raw_output_log
```

# Configuration

No additional configuration is needed once the plugin is enabled.