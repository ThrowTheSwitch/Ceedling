# Build Warnings Log

Capture build process warnings from command line tools to a plain text log file and to
optional SARIF and JSON reports.

## Overview

This plugin collects the warnings that command line tools print as a build preprocesses,
compiles, and links, and writes them to a plain text log file when the build ends. Each
build context — `test`, `release`, or a plugin’s build such as `gcov` — gets its own log
in `<build root>/artifacts/<context>/`, written even when the build ends in an error.

Warnings from Ceedling itself or from code generation do not appear in these logs; only
the output of the preprocessing, compilation, and linking tools is collected.

Each warning keeps the lines that explain it. GCC and Clang print a warning with its
source line and a caret marking the spot, often after an `In function` or
`In file included from` line, and the log holds all of it:

```text
a.c: In function 'a':
a.c:2:21: warning: unused variable ’spare' [-Wunused-variable]
    2 | int a( void ) { int spare; return 0; }
      |                     ^~~~~
```

Each distinct warning is logged once per build context. A warning in a header that many
files include appears once, with the include chain of the first file that reported it.

Output from other toolchains, whose warnings do not follow GCC’s format, is collected a
line at a time.

The same warnings can also be written as [SARIF](#sarif-report) and/or [JSON](#json-report)
reports for other tools to read, such as a CI service that marks each warning on the line
of code it concerns.

## Setup

Enable the plugin in your Ceedling project file:

```yaml
:plugins:
  :enabled:
    - report_build_warnings_log
```

## Configuration

All settings are optional and live under `:report_build_warnings_log`.

| Setting | Purpose | Default |
|---|---|---|
| `:filename` | Base name of each report file | `warnings` |
| `:reports` | Reports to write: any of `:text`, `:sarif`, `:json` | `:text` |
| `:patterns` | Regular expressions that find warnings, replacing the default | any line mentioning “warning” |
| `:excludes` | Regular expressions that drop collected warnings | none |

### Filename

`:filename` names each report file, and each report adds its own extension: `.log` for
the text log, `.sarif` for SARIF, and `.json` for JSON. An extension given here is
replaced by the report’s own.

```yaml
:report_build_warnings_log:
  :filename: more_better_filename
```

This writes `more_better_filename.log` and, if configured, `more_better_filename.sarif`
and/or `more_better_filename.json`.

### Reports

`:reports` lists the reports to write for each build context. Entries may be symbols or
strings in any letter case. With no `:reports` setting, or an empty list, the plugin writes
the text log alone.

```yaml
:report_build_warnings_log:
  :reports:
    - :text
    - :sarif
    - :json
```

The text log is written only for a build context with warnings. The SARIF and JSON
reports are written for every build context that compiled, linked, or preprocessed
anything, even without warnings. A CI step that reads one therefore always finds it, and
an empty report tells a code scanning service that earlier warnings are gone.

An entry that is not one of these reports stops the build with an error naming it.

#### Text report

The text log, `warnings.log`, holds each warning as the tools printed it, as shown in the
[overview](#overview).

#### SARIF report

[SARIF](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html), the Static
Analysis Results Interchange Format, is the OASIS standard JSON format for the findings
of compilers, linters, and other analysis tools. Many services and editors read it,
showing each finding on the line of code it concerns:

- GitHub [code scanning](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
  shows SARIF results as alerts and as annotations on pull requests.
- Azure DevOps, SonarQube, and Jenkins’ Warnings Next Generation plugin import SARIF files.
- Microsoft’s [SARIF Viewer](https://marketplace.visualstudio.com/items?itemName=MS-SarifVSCode.sarif-viewer)
  for VS Code opens a SARIF file and steps through its results in your editor.

Microsoft’s [SARIF tutorials](https://github.com/microsoft/sarif-tutorials) introduce the
format in more depth.

`warnings.sarif` is a SARIF 2.1.0 log with one run by Ceedling for its build context.
Each warning is a result:

- Its `ruleId` is the warning’s flag, such as `-Wunused-variable`. The run’s rules list
  each flag.
- Its `level` is the diagnostic’s severity: `warning`, `error`, or `note`, which also
  covers a `remark`.
- Its `message` is the diagnostic’s text.
- Its location is the file, line, and column. A relative path is relative to your
  project, which SARIF calls `%SRCROOT%`, and an absolute path is a `file:` URI.
- Its `properties` hold the warning’s context lines and its full text as printed.

The run’s `automationDetails` `id` names the build context, such as `test/`, so a service
can tell the reports of different contexts apart.

The warning in the [overview](#overview) becomes this SARIF report:

```json
{
  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Ceedling",
          "version": "1.2.0",
          "informationUri": "https://www.throwtheswitch.org/ceedling",
          "rules": [
            {
              "id": "-Wunused-variable"
            }
          ]
        }
      },
      "automationDetails": {
        "id": "test/"
      },
      "results": [
        {
          "ruleId": "-Wunused-variable",
          "level": "warning",
          "message": {
            "text": "unused variable ’spare'"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "a.c",
                  "uriBaseId": "%SRCROOT%"
                },
                "region": {
                  "startLine": 2,
                  "startColumn": 21
                }
              }
            }
          ],
          "properties": {
            "context": [
              "a.c: In function 'a':"
            ],
            "text": "a.c: In function 'a':\na.c:2:21: warning: unused variable ’spare' [-Wunused-variable]\n    2 | int a( void ) { int spare; return 0; }\n      |                     ^~~~~\n"
          }
        }
      ]
    }
  ]
}
```

A warning from output that does not follow GCC’s format has no file or line, so its result
is a message alone. Code scanning services that require a location, as GitHub does, do not
show such a result.

This GitHub Actions step uploads a test build’s SARIF report to code scanning. The upload
needs the workflow’s `security-events: write` permission.

```yaml
- name: Upload build warnings
  if: always()
  uses: github/codeql-action/upload-sarif@v4
  with:
    sarif_file: build/artifacts/test/warnings.sarif
    category: ceedling-test
```

#### JSON report

`warnings.json` is a simple JSON layout for scripts, such as one that fails a CI job when
a build has warnings or tracks their count over time. It names the build context and
lists each warning’s file, line, column, severity, flag, message, context lines, and full
text. A field the warning’s output does not provide, such as the file of a warning not in
GCC’s format, is `null`.

The warning in the [overview](#overview) becomes this JSON report:

```json
{
  "context": "test",
  "warnings": [
    {
      "file": "a.c",
      "line": 2,
      "column": 21,
      "severity": "warning",
      "flag": "-Wunused-variable",
      "message": "unused variable ’spare'",
      "context": [
        "a.c: In function 'a':"
      ],
      "text": "a.c: In function 'a':\na.c:2:21: warning: unused variable ’spare' [-Wunused-variable]\n    2 | int a( void ) { int spare; return 0; }\n      |                     ^~~~~\n"
    }
  ]
}
```

### Patterns

By default, any diagnostic or line mentioning “warning”, in any letter case, is collected.
`:patterns` replaces that with your own regular expressions, matched against each
diagnostic line. A warning is collected when any pattern matches. This suits a toolchain
whose warnings take a particular form, or collecting remarks as well as warnings:

```yaml
:report_build_warnings_log:
  :patterns:
    - ': warning:'
    - ': remark:'
    - 'Warning\[Pe\d+\]'
```

Patterns are case sensitive. Begin one with `(?i)` to ignore case.

### Excludes

`:excludes` drops any collected warning that one of its regular expressions matches,
anywhere in the warning’s text, context lines included. Use it to quiet warnings you have
already accepted, such as those from third-party code, or to prevent false positive
matches.

```yaml
:report_build_warnings_log:
  :excludes:
    - 'third_party/'
    - '-Wunused-function'
```

An entry under `:patterns` or `:excludes` that is not a valid regular expression stops the
build with an error naming it.

<br/><br/>
