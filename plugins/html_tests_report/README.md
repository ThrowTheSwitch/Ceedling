html_tests_report
================

## Overview

The html_tests_report plugin creates an HTML file of test results,
which makes the results easier to read. The HTML file is output to the appropriate
`<build_root>/artifacts/` directory (e.g. `artifacts/test/` for test tasks,
`artifacts/gcov/` for gcov, or `artifacts/bullseye/` for bullseye runs).

## Setup

Enable the plugin in your project.yml by adding `html_tests_report` to the list
of enabled plugins.

``` YAML
:plugins:
  :enabled:
    - html_tests_report
```

## Configuration

Optionally configure the output / artifact filename in your project.yml with
the `artifact_filename` configuration option. The default filename is
`report.html`.

You can also configure the path that this artifact is stored. This can be done
by setting `path`. The default is that it will be placed in a subfolder under
the `build` directory.

If you use some means for continuous integration, you may also want to add
.xsl file to CI's configuration for proper parsing of .xml report.

``` YAML
:html_tests_report:
  :artifact_filename: report_test.html
```
