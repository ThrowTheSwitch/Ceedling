# Coverage Reporting

The `gcov` plugin is one of Ceedling’s most used features. It orchestrates GCC 
coverage instrumentation and use of the `gcov` tool to generate code coverage 
for test builds. Optionally, it can generate HTML, XML, JSON, and text reports 
via the GCovr and/or ReportGenerator reporting tools.

See the full [Gcov Plugin documentation](../plugins/gcov/index.md) for concepts, 
installation, troubleshooting, and worked examples.

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :summaries: FALSE

:gcov:
  :utilities:
    - gcovr

:gcov:
  :reports:
    - HtmlBasic
```

---

## `gcov` Plugin Settings

Options avialable directly beneath `:gcov`.

### `:summaries`

Enable or disable automatic console coverage summaries printed after each
`gcov:` task.

**Default:** `TRUE`

```yaml
:gcov:
  :summaries: FALSE
```

---

### `:mcdc`

Enable or disable Modified Condition / Decision Coverage in coverage results.
This feature is dependent on minimum tool versions.

**Default:** `FALSE`

```yaml
:gcov:
  :mcdc: TRUE
```

---

### `:untested_sources`

Enable or disable coverage compilation for all untested source files.
When enabled, coverage results will exist in the final report for all source
files in the project (untested source files will be listed with 0% coverage.)

**Default:** `TRUE`

```yaml
:gcov:
  :untested_sources: TRUE
```

---

### `:utilities`

List of report generation utilities to enable. Valid values are `gcovr` and
`ReportGenerator`. Either or both may be specified.

**Default:** `[gcovr]` (when `:reports:` is configured and `:utilities:` is absent)

```yaml
:gcov:
  :utilities:
    - gcovr
    - ReportGenerator
```

---

### `:report_task`

When `TRUE`, disables automatic report generation after `gcov:` tasks and
instead enables a separate `report:gcov` Ceedling task for on-demand report
generation.

**Default:** `FALSE`

```yaml
:gcov:
  :report_task: TRUE
```

---

### `:reports`

List of report types to generate. When empty or absent, report generation
(but not coverage summaries) is disabled.

```yaml
:gcov:
  :reports:
    - HtmlBasic
    - HtmlDetailed
    - ...
```

| Report option | gcovr | ReportGenerator |
|---|:---:|:---:|
| `HtmlBasic` | ✓ | ✓ |
| `HtmlDetailed` | ✓ | ✓ |
| `Text` | ✓ | ✓ |
| `Cobertura` | ✓ | ✓ |
| `SonarQube` | ✓ | ✓ |
| `JSON` | ✓ | |
| `HtmlInline` | | ✓ |
| `HtmlInlineAzure` | | ✓ |
| `HtmlInlineAzureDark` | | ✓ |
| `HtmlChart` | | ✓ |
| `MHtml` | | ✓ |
| `Badges` | | ✓ |
| `CsvSummary` | | ✓ |
| `Latex` | | ✓ |
| `LatexSummary` | | ✓ |
| `PngChart` | | ✓ |
| `TeamCitySummary` | | ✓ |
| `lcov` | | ✓ |
| `Xml` | | ✓ |
| `XmlSummary` | | ✓ |

---

## GCovr Settings

All options below live under `:gcov:` ↳ `:gcovr:`. Reports are written to
`<build root>/artifacts/gcov/gcovr/`.

### `:report_root`

Root directory of your source files; file names in reports are relative to
this path.

**Default:** `"."` (current directory)

---

### `:config_file`

Load a `gcovr` configuration file. (`gcovr --config`)

**Default:** `gcovr.cfg` in the `:report_root` directory, if present.

---

### `:fail_under_line`

Exit with status 2 if total line coverage is below this percentage.
(`gcovr --fail-under-line`)

**Values:** `1`–`100`

---

### `:fail_under_branch`

Exit with status 4 if total branch coverage is below this percentage.
(`gcovr --fail-under-branch`)

**Values:** `1`–`100`

---

### `:fail_under_decision`

Exit with status 8 if total decision coverage is below this percentage.
(`gcovr --fail-under-decision`)

**Values:** `1`–`100`

---

### `:fail_under_function`

Exit with status 16 if total function coverage is below this percentage.
(`gcovr --fail-under-function`)

**Values:** `1`–`100`

---

### `:exception_on_fail`

When any `:fail_under_*` threshold is set, raise a build-breaking exception
instead of only logging a warning.

**Default:** `FALSE`

---

### `:source_encoding`

Source file character encoding. (`gcovr --source-encoding`)

**Default:** system default (typically `UTF-8`)

---

### `:branches`

Report branch coverage instead of line coverage. Applies to text reports only.
(`gcovr --branches`)

---

### `:sort_uncovered`

Sort report entries by increasing number of uncovered lines. Applies to text
and HTML reports. (`gcovr --sort-uncovered`)

---

### `:sort_percentage`

Sort report entries by increasing percentage of uncovered lines. Applies to
text and HTML reports. (`gcovr --sort-percentage`)

---

### `:print_summary`

Print a brief line- and branch-coverage summary to stdout in addition to any
other reports. (`gcovr --print-summary`)

---

### `:report_include`

Keep only source files matching this regular expression filter.
(`gcovr --filter`)

**Example:** `"^src"`

---

### `:report_exclude`

Exclude source files matching this regular expression filter.
(`gcovr --exclude`)

**Example:** `"^vendor.*|^build.*|^test.*|^lib.*"`

---

### `:gcov_filter`

Keep only `.gcov` data files matching this regular expression filter.
(`gcovr --gcov-filter`)

---

### `:gcov_exclude`

Exclude `.gcov` data files matching this regular expression filter.
(`gcovr --gcov-exclude`)

---

### `:exclude_directories`

Exclude directories matching this regular expression filter when searching for
raw coverage files. (`gcovr --exclude-directories`)

---

### `:gcov_executable`

Use a specific `gcov` executable instead of the one on `PATH`.
(`gcovr --gcov-executable`)

---

### `:exclude_unreachable_branches`

Exclude branch coverage from lines without useful source code.
(`gcovr --exclude-unreachable-branches`)

---

### `:exclude_throw_branches`

Exclude compiler-generated exception-handling branches from branch coverage.
(`gcovr --exclude-throw-branches`)

---

### `:merge_mode_function`

Controls how `gcovr` handles multiple coverage entries for the same function
(e.g. when Ceedling tests the same source under multiple build configurations).

**Default:** `merge-use-line-max`

See the [gcovr merging docs](https://gcovr.com/en/stable/guide/merging.html)
for all valid values.

---

### `:use_gcov_files`

Use existing `.gcov` files on disk instead of running `gcov` again.
(`gcovr --use-gcov-files`)

**Default:** `FALSE`

---

### `:gcov_ignore_parse_errors`

Skip lines with parse errors in `.gcov` files rather than exiting with an
error. (`gcovr --gcov-ignore-parse-errors`)

---

### `:object_directory`

Override normal working-directory detection for `.gcda` / `.gcno` files.
(`gcovr --object-directory`)

---

### `:keep`

Retain intermediate `.gcov` files after processing. (`gcovr --keep`)

---

### `:delete`

Delete `.gcda` files after processing. (`gcovr --delete`)

---

### `:threads`

Number of parallel threads to use during report generation. (`gcovr -j`)

---

### `:html_artifact_filename`

Override the default HTML report output filename.

---

### `:html_title`

Title text for the HTML report. (`gcovr --html-title`)

**Default:** `Head`

---

### `:html_medium_threshold`

Coverage percentage below which a value is marked as low coverage in the HTML
report. Must be ≤ `:html_high_threshold`. (`gcovr --html-medium-threshold`)

**Default:** `75.0`

---

### `:html_high_threshold`

Coverage percentage below which a value is marked as medium coverage in the
HTML report. Must be ≥ `:html_medium_threshold`. (`gcovr --html-high-threshold`)

**Default:** `90.0`

---

### `:html_absolute_paths`

Use absolute paths when linking to detailed reports in the HTML output.
(`gcovr --html-absolute-paths`)

**Default:** relative links

---

### `:html_encoding`

Override the declared character encoding in the HTML report.
(`gcovr --html-encoding`)

**Default:** `UTF-8`

---

### `:cobertura_pretty`

Pretty-print the Cobertura XML report. (`gcovr --xml-pretty`)

**Default:** `FALSE`

---

### `:cobertura_artifact_filename`

Override the default Cobertura XML report output filename.

---

### `:sonarqube_artifact_filename`

Override the default SonarQube XML report output filename.

---

### `:json_pretty`

Pretty-print the JSON report. (`gcovr --json-pretty`)

**Default:** `FALSE`

---

### `:json_artifact_filename`

Override the default JSON report output filename.

---

### `:text_artifact_filename`

Override the default text report output filename. When unset the text report
is printed to the console.

---

## ReportGenerator Settings

All options below live under `:gcov:` ↳ `:report_generator:`. Reports are
written to `<build root>/artifacts/gcov/ReportGenerator/`.

### `:history_directory`

Optional directory for storing persistent coverage history, enabling
coverage-trend charts across builds.

---

### `:plugins`

Optional semicolon-separated list of plugin DLL files for custom report types
or custom history storage.

**Example:** `plugin.dll;*.dll`

---

### `:assembly_filters`

Optional semicolon-separated list of assembly inclusion/exclusion filters.
Prefix `+` to include, `-` to exclude. Exclusions take precedence. Wildcards
allowed (not regular expressions).

**Example:** `+MyLib;-ThirdParty`

---

### `:class_filters`

Optional semicolon-separated list of class inclusion/exclusion filters. Same
prefix and wildcard rules as `:assembly_filters`.

---

### `:file_filters`

Optional semicolon-separated list of file inclusion/exclusion filters. Same
prefix and wildcard rules as `:assembly_filters`.

**Example:** `"-./vendor/*;-./build/*;-./test/*;+./src/*"`

---

### `:verbosity`

Verbosity level for ReportGenerator log output.

**Values:** `Verbose`, `Info`, `Warning`, `Error`, `Off`

**Default:** `Warning`

---

### `:tag`

Optional build tag or version label embedded in the report.

---

### `:gcov_exclude`

Optional list of regular expressions; `.gcov` notes files whose paths match
are excluded from report generation.

```yaml
:gcov:
  :report_generator:
    :gcov_exclude:
      - <regex>
```

---

### `:threads`

Number of parallel threads to use during report generation.

**Default:** `1`

---

### `:custom_args`

Optional list of additional command-line arguments passed directly to
ReportGenerator. Useful for configuring Risk Hotspots and other settings not
covered by the options above. See the
[ReportGenerator settings wiki](https://github.com/danielpalme/ReportGenerator/wiki/Settings).

```yaml
:gcov:
  :report_generator:
    :custom_args:
      - <argument>
```

<br/><br/>
