# Ceedling Plugin: Warnings Report

# Plugin Overview

This plugin captures warning messages output by command line tools throughout a
build.

At the end of a build, any collected warning messages are written to one or more
plain text log files.

Warning messages are collected for all compilation-related builds and
differentiated by build context — `test`, `release`, or plugin-modified build 
(e.g. `gcov`).

Ceedling warning messages or warning messages from code generation will not
appear in log files; warnings are only collected from build step command line
tools for the predefined build steps of preprocessing, compilation, and
linking.

Log files are written to `<build root>/artifacts/<context>/`.

# Setup & Configuration

Enable the plugin in your Ceedling project file by adding `warnings_report` to
the list of enabled plugins.

```yaml
:plugins:
  :enabled:
    - warnings_report
```

To change the default filename of `warning.log`, add your desired filename to
your configuration file.

```yaml
:warnings_report:
  :filename: more_better_filename.ext
```
