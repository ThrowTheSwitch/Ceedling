# ReportGenerator Configuration

The `ReportGenerator` utility may be configured with the following configuration items.

All generated reports are found in `<build root>/artifacts/gcov/ReportGenerator/`.

## Example configuration

```yaml
:gcov:
  :report_generator:
    :history_directory: build/artifacts/gcov/history
    :file_filters: "-./vendor/*;-./build/*;-./test/*;+./src/*"
    :verbosity: Warning
    :tag: "release-1.4.0"
    :num_parallel_threads: 4
    :gcov_exclude:
      - some_excluded_file
    :custom_args:
      - "-title:MyProject"
```

## Results filtering

This plugin filters coverage results for `reportgenerator` coverage reporting
in two separate stages, each with its own defaults.

### Coverage generation filtering

Before `reportgenerator` ever runs, this plugin runs `gcov` itself against each
`.gcno` file produced by the coverage test build, skipping any that match an 
exclusion pattern — no `.gcov` data is ever produced for a skipped file, so 
nothing downstream can put it back into a report.

By default this skips:

- **Test files** — matched by `:test_file_prefix`.
- **Mocks** — matched by `:mock_prefix`.
- **Test runners** — any filename containing `_runner`.
- **Vendored Unity and CMock sources** — `unity.gcno` and `cmock.gcno` by
  name.

Given `:test_file_prefix` ⇒ `test_` and CMock's default `:mock_prefix` ⇒
`Mock`, the equivalent filename-fragment patterns are:

```
test_[^\/\\]*
Mock[^\/\\]*
[^\/\\]*_runner[^\/\\]*
unity
cmock
```

These combine with whatever you add via [`:gcov_exclude`](#gcov_exclude)
below. Your patterns extend this list, they don't replace it.

### Report filtering

Separately, once `.gcov` files exist, ReportGenerator's own `-filefilters:`
argument controls which of them actually appear in the generated report(s).
By default this excludes:

1.  **Test paths** — every file anywhere under each of your configured
    `:paths` ↳ `:test` directories, not only files matching
    `:test_file_prefix`. A support subdirectory nested under a test path
    (e.g. `test/support/`) is excluded as a side effect of this — the whole
    tree goes, not just prefixed test files.

    Given a `:paths` ↳ `:test` entry of `test/`:
    ```
    -./test/**/*
    ```

1.  **The build root** — every generated and vendored file: mocks, test
    runners, Partials output, Unity, CMock, CException.

    Given `:build_root` ⇒ `build/`:
    ```
    -./build/**/*
    ```

1.  **Partial-generated files** — only when `:use_partials` is enabled, any
    file whose name starts with Ceedling's Partial filename prefix, wherever
    it's found (not only under the build root).

    ```
    -ceedling_partial_*
    ```

These patterns are generated automatically and placed ahead of whatever you
provide via [`:file_filters`](#file_filters) below.

### Overriding the defaults

Neither filtering stage above can be overridden or narrowed by plugin
configuration — only added to.

For [coverage generation filtering](#coverage-generation-filtering),
[`:gcov_exclude`](#gcov_exclude) only ever adds more exclusion patterns; there
is no plugin option to disable one of the built-in exclusions, and no way to
resurrect `.gcov` data for a file `gcov` was never run against in the first
place.

For [report filtering](#report-filtering), the natural instinct is to reach
for [`:custom_args`](#custom_args) to pass a second, conflicting
`-filefilters:` argument, but this is not an option because of ReportGenerator's
rules and the order in which the filters are provided by the plugin.

In short, there's no supported way to broaden what this plugin reports
beyond its defaults. If you need to override coverage reporting filtering, 
use the [Gcovr option for this pluing](gcovr.md) instead. Its
`:config_file` option hands full control to a `gcovr` configuration file,
bypassing Ceedling's generated exclusions entirely (see
[Gcovr's Results filtering](gcovr.md#results-filtering)).

## Plugin configuration

### `:history_directory`

Optional directory for storing persistent coverage information. Can be used
in future reports to show coverage evolution.

---

### `:plugins`

Optional plugin files for custom reports or custom history storage (separated
by semicolon).

**Example:** `plugin.dll;*.dll`

---

### `:assembly_filters`

Optional list of assemblies that should be included or excluded in the
report (separated by semicolon). Exclusion filters take precedence over
inclusion filters. Wildcards are allowed, but not regular expressions.

**Example:** `+<included>;-<excluded>`

---

### `:class_filters`

Optional list of classes that should be included or excluded in the report
(separated by semicolon). Exclusion filters take precedence over inclusion
filters. Wildcards are allowed, but not regular expressions.

**Example:** `+<included>;-<excluded>`

---

### `:file_filters`

Optional list of files that should be included or excluded in the report
(separated by semicolon). Exclusion filters take precedence over inclusion
filters regardless of order. Wildcards are allowed, but not regular
expressions.

This plugin places your own patterns first, ahead of the exclusions it
generates automatically for test paths, the build root, and (when Partials
are in use) Partial-generated files (see
[Report filtering](#report-filtering) above for exactly what those defaults
cover). Because exclusions always win, your patterns can add further
exclusions or includes but cannot override or remove one of those defaults;
see [Overriding the defaults](#overriding-the-defaults) above.

**Example:** `"-./vendor/*;-./build/*;-./test/*;-./lib/*;+./src/*"`

---

### `:verbosity`

The verbosity level of the log messages.

**Values:** `Verbose`, `Info`, `Warning`, `Error`, `Off`

**Default:** `Warning`

---

### `:tag`

Optional tag or build version.

---

### `:gcov_exclude`

Optional list of one or more regular expressions to exclude gcov notes
(`.gcno`) files that match these filters from coverage processing — these
files are never run through `gcov` at all. A trailing `.gcov` or `.gcno`
suffix on a pattern is stripped automatically, so either form works.

Ceedling combines your patterns with exclusions it generates automatically
for test files, mocks, test runners, and vendored Unity/CMock sources (see
[Coverage generation filtering](#coverage-generation-filtering) above for
exactly what these cover). Your patterns can only add further exclusions;
there's no way to override or remove one of the defaults — see
[Overriding the defaults](#overriding-the-defaults) above.

```yaml
:gcov:
  :report_generator:
    :gcov_exclude:
      - <regex>
      - ...
```

**Default:** `[]`

---

### `:num_parallel_threads`

Optionally set the number of threads ReportGenerator uses in parallel. Drives
both of ReportGenerator's own `numberOfReportsParsedInParallel` and
`numberOfReportsMergedInParallel` settings together.

**Default:** unset (ReportGenerator's own default applies)

---

### `:custom_args`

Optional list of one or more command line arguments to pass to Report
Generator. Useful for configuring Risk Hotspots and other settings not
covered by the options above. See the
[ReportGenerator settings wiki](https://github.com/danielpalme/ReportGenerator/wiki/Settings).

Note: This can be accomplished with Ceedling's tool configuration options
outside of plugin configuration but is supported here to collect
configuration options in one place.

```yaml
:gcov:
  :report_generator:
    :custom_args:
      - <argument>
      - ...
```

**Default:** `[]`

<br/><br/>
