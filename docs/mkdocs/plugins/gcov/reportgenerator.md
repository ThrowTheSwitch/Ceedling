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
filters. Wildcards are allowed, but not regular expressions. Ceedling places
your own patterns first, ahead of the exclusions it generates automatically
for test paths, the build root, and (when Partials are in use) Partial
source files, so your patterns take precedence.

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

### `:fail_under_line`

Break the build if the total line coverage is less than this minimum
percentage. (ReportGenerator `minimumCoverageThresholds:lineCoverage`)

**Values:** `1`–`100`

---

### `:fail_under_branch`

Break the build if the total branch coverage is less than this minimum
percentage. (ReportGenerator `minimumCoverageThresholds:branchCoverage`)

**Values:** `1`–`100`

---

### `:fail_under_method`

Break the build if the total method coverage is less than this minimum
percentage. (ReportGenerator `minimumCoverageThresholds:methodCoverage`)

**Values:** `1`–`100`

---

### `:fail_under_full_method`

Break the build if the total full method coverage is less than this minimum
percentage. (ReportGenerator `minimumCoverageThresholds:fullMethodCoverage`)

**Values:** `1`–`100`

---

### `:gcov_exclude`

Optional list of one or more regular expressions to exclude gcov notes
(`.gcno`) files that match these filters from coverage processing — these
files are never run through `gcov` at all. A trailing `.gcov` or `.gcno`
suffix on a pattern is stripped automatically, so either form works.

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
