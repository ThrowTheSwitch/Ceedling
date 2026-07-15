# Example Usage

!!! note
    Unless disabled, console coverage summaries are always printed after a
    `bullseye:` task regardless of HTML report generation options.

## Automatic HTML report generation (default)

By default, this plugin generates an HTML report after any `bullseye:` task.

```yaml
:plugins:
  :enabled:
    - bullseye

:bullseye:
  :report_task: FALSE  # Disabled by default -- shown for completeness
```

```shell
 > ceedling bullseye:all
```

## Manual HTML report generation task

If the `:report_task:` configuration option is enabled, the HTML report is
not automatically generated after test suite coverage builds. Instead,
report generation is triggered by the `report:bullseye` task.

```yaml
:plugins:
  :enabled:
    - bullseye

:bullseye:
  :report_task: TRUE
```

With the separate reporting task enabled, it can be used like any other
Ceedling task.

```shell
 > ceedling bullseye:all report:bullseye
```

or

```shell
 > ceedling bullseye:all

 > ceedling report:bullseye
```

## Compiling untested sources for complete reporting

By default, source files no test exercises are logged as a warning and left
out of coverage reporting entirely. Setting `:untested_sources: :compile`
compiles them anyway, so every project source appears in reporting (at 0%
coverage for anything genuinely untested).

```yaml
:plugins:
  :enabled:
    - bullseye

:bullseye:
  :untested_sources: :compile
```

```shell
 > ceedling bullseye:all
```

If an untested source fails to compile on its own (missing defines, flags,
or platform stand-ins a full test build would otherwise provide), iterate on
just that problem with the standalone task:

```shell
 > ceedling bullseye:untested_sources
```

## Minimal console-only configuration

For a project that only wants console coverage summaries with no HTML
report at all, simply enable the plugin with no further configuration —
report generation requires no `:reports:`-style opt-in the way `gcov`'s
advanced reporting does, so leaving `:bullseye:` unconfigured already
produces an HTML report by default. To suppress it, disable the report task
and never invoke `report:bullseye`:

```yaml
:plugins:
  :enabled:
    - bullseye

:bullseye:
  :report_task: TRUE  # Report only generated if report:bullseye is explicitly run
```

<br/><br/>
