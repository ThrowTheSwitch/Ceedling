# Ceedling Plugin: Raw Test Output Report

# Plugin Overview

This plugin gathers console output from test executables into log files.
Unity-based test executables print test case pass/fail status messages and test
case accounting to $stdout. This plugin filters out this expected output leaving 
log files containing only extra console output.

Ceedling and Unity cooperate to extract console statements unrelated to test
cases and present them through $stdout plugins. This plugin captures the same
output to log files instead.

Debugging in unit tested code is often accomplished with simple `printf()`-
style calls to dump information to the console. This plugin can be helpful
in supporting debugging efforts.

Log files are only created if test executables produce console output as
described above and are named for those test executables.

Builds are differentiated by build context — `test`, `release`, or
plugin-modified build (e.g. `gcov`). Log files are written to `<build
root>/artifacts/<context>/<test file>.raw.log`.

# Setup & Configuration

Enable the plugin in your Ceedling project by adding `raw_tests_output_report`
to the list of enabled plugins.

``` YAML
:plugins:
  :enabled:
    - raw_tests_output_report
```
