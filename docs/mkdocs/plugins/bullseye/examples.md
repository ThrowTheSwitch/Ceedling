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

## Using a floating license manager file

If your Bullseye license is a floating/evaluation license (see
[Licensing](licensing.md)), point the plugin at your organization's shared
license manager file so every Bullseye tool invocation can find it.

```yaml
:plugins:
  :enabled:
    - bullseye

:bullseye:
  :license_manager_file: /path/to/shared/bullseye.lmgr
```

```shell
 > ceedling bullseye:all
```

This setting is unnecessary — and has no effect — for node-locked/unlimited
licenses, which are activated once at installation time independent of any
per-build configuration.

## Minimal console-only configuration

Unlike `gcov`, this plugin produces an HTML report by default with no
`:reports:`-style opt-in required — so a project that wants only console
coverage summaries needs one setting to suppress it: `:report_task: TRUE`.
This disables automatic HTML generation in favor of the on-demand
`report:bullseye` task; as long as that task is never invoked, no HTML
report is produced at all.

```yaml
:plugins:
  :enabled:
    - bullseye

:bullseye:
  :report_task: TRUE  # Report only generated if report:bullseye is explicitly run
```

<br/><br/>
