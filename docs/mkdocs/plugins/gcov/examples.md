# Example Usage

!!! note
    Unless disabled, basic coverage summaries are always printed to the 
    console regardless of report generation options.

## Automatic report generation (default)

If coverage report generation is configured, the plugin defaults to running 
reports after any `gcov:` task.

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :utilities:
    - gcovr            # Enabled by default -- shown for completeness
  :report_task: FALSE  # Disabled by default -- shown for completeness
  :reports:            # See later section for report configuration
    - HtmlBasic

  ...                  # Further configuration for reporting (not shown)

```

```shell
 > ceedling gcov:all
```

## Report generation manual task

If the `:report_task:` configuration option is enabled, reports are not 
automatically generaed after test suite coverage builds. Instead, report 
generation is triggered by the `report:gcov` task.

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :utilities:
    - gcovr            # Enabled by default -- shown for completeness
  :report_task: TRUE
  :reports:            # See later section for report configuration
    - HtmlBasic        # Enabled by default -- shown for completeness

  ...                  # Further configuration for reporting (not shown)

```

With the separate reporting task enabled, it can be used like any other Ceedling task.

```shell
 > ceedling gcov:all report:gcov
```

or 

```shell
 > ceedling gcov:all

 > ceedling report:gcov
```

## Full report generation

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :summaries: FALSE              # Simple coverage summaries to console disabled
  :reports:                      # `gcovr` tool enabled by default
    - HtmlDetailed
    - Text
    - Cobertura
  :gcovr:                        # `gcovr` common and report-specific options
    :report_root: "../../"       # Atypical layout -- project.yml is inside a subdirectoy below <build root>
    :sort_percentage: TRUE
    :sort_uncovered: FALSE
    :html_medium_threshold: 60
    :html_high_threshold: 85
    :print_summary: TRUE
    :threads: 4
    :keep: FALSE
```

<br/><br/>
