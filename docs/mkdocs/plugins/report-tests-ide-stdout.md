# IDE Test Suite Console Report

Prints test suite results to the console (`$stdout`), listing failed and ignored
tests in a form IDEs read as problems.

## Plugin Overview

This plugin replaces the more commonly used "pretty" test report plugin that defaults
for command line use. Like its sibling, it collects raw test results from the test 
executables of your test suite and prints them in summary form.

The difference is how it lists failed and ignored tests. By default, each one
prints in the shape of a GCC diagnostic. An IDE that reads GCC output turns each
line into a problem that links to the test.

Example:

```
test/TestModel.c:21:1: error: testInitShouldCallSchedulerAndTemperatureFilterInit: Function TaskScheduler_Init() called more times than expected.
```

A failed test is an `error`. An ignored test is a `warning`. The line names the
test file, the test’s line, the test case, and Unity’s message.

Unity reports a line but no column, so the column is always `1`.

Eclipse CDT, VS Code, and CLion all read this shape. So do many other IDEs and
tools that understand GCC output, including ones not covered here.

## Setup

Enable the plugin in your project.yml by adding `report_tests_ide_stdout` to the
list of enabled plugins instead of any other `report_tests_*_stdout` plugin.

```YAML
:plugins:
  :enabled:
    - report_tests_ide_stdout
```

## Configuration

Two settings shape the report. Neither is required.

```YAML
:report_tests_ide_stdout:
  :format: :gcc            # Default
  :absolute_paths: TRUE    # No default. Each format sets its own path form.
```

### `:format`

`:format` chooses how each failed and ignored test is listed.

| `:format` | Lines | Paths unless `:absolute_paths` is set |
|---|---|---|
| `:gcc` | GCC diagnostic shape (default) | Relative |
| `:legacy` | The shape before Ceedling 1.2.0 | Relative |
| `:vscode` | Same as `:gcc` | Relative |
| `:eclipse` | Same as `:gcc` | Relative |
| `:clion` | Same as `:gcc` | Absolute and required |

Use `:gcc` with any tool that reads GCC output.

The IDE names are shortcuts (other settings are not required when these aliases
are used). Each stands for the `:gcc` settings that IDE needs. More names may be 
added later.

A format may be written as a symbol or a string, in any letter case.

`:legacy` restores the lines this plugin printed before Ceedling 1.2.0. Every line
of a message repeats the file, line, and test case, and the message is quoted.

```
test/TestModel.c:21:testInitShouldCallSchedulerAndTemperatureFilterInit: "Function TaskScheduler_Init() called more times than expected."
```

Few IDEs read `:legacy` lines as problems without extra configuration.

### `:absolute_paths`

Paths are relative to your project’s root unless a format says otherwise. Set
`:absolute_paths` to `TRUE` for full paths. Set it to `FALSE` for relative paths.

When `:absolute_paths` is not set, each format’s own path form applies. When it is
set, it overrides that path form, unless the named IDE cannot read the result.
CLion’s output filters find only absolute paths. So `:clion` with
`:absolute_paths: FALSE` stops the build with a configuration error.

```YAML
:report_tests_ide_stdout:
  :format: :eclipse
  :absolute_paths: TRUE
```

### Multi-line messages

The first line of a message goes on the test’s line. The remaining lines follow,
indented four spaces. Your IDE shows one problem for the test, and the console
keeps the whole message.

```
test/TestModel.c:30:1: error: testFilterShouldReset: Expected 5 Was 4
    Filter state at failure: RESET_PENDING
```

## Example Output

```sh
 > ceedling test:Model
```

```
--------------------
IGNORED TEST SUMMARY
--------------------
test/TestModel.c:36:1: warning: testFilterShouldSettle: Awaiting new sensor driver

-------------------
FAILED TEST SUMMARY
-------------------
test/TestModel.c:21:1: error: testInitShouldCallSchedulerAndTemperatureFilterInit: Function TaskScheduler_Init() called more times than expected.

--------------------
OVERALL TEST SUMMARY
--------------------
TESTED:  3
PASSED:  1
FAILED:  1
IGNORED: 1

---------------------
BUILD FAILURE SUMMARY
---------------------
 • Unit test failures.
```

The Gcov, Bullseye, and Valgrind plugins print their test results through this
plugin when it is enabled. Their failed and ignored tests are listed the same way.

## IDE Setup

An IDE reads only output it captures. Run Ceedling from within the IDE, as a build,
task, or tool, as each section below describes.

### Eclipse CDT

Eclipse CDT finds problems by matching build output against regular expressions.
Its GCC error parser reads this plugin’s default lines.

1. Use a Makefile project that runs Ceedling as its build. In _Project Properties_ ↳
   _C/C++ Build_ ↳ _Builder Settings_, clear _Use default build command_ and set the
   build command to `ceedling`. On the _Behavior_ tab, set the build target to
   `test:all`.
1. In _C/C++ Build_ ↳ _Settings_ ↳ _Error Parsers_, enable _GNU gcc/g++ Error Parser_.
1. Build the project. Failed tests appear in the _Problems_ view as errors, and
   ignored tests as warnings.

Eclipse reads output only from builds. Ceedling run in a terminal or as an
external tool creates no Eclipse problems to be matched and linked.

Eclipse checks a few special-purpose patterns before its error pattern. A failure
message containing the words _required from_ or _instantiated from_ appears as
information rather than an error.

### VS Code

VS Code reads problems from a task’s output through a problem matcher. The C/C++
extension supplies a `$gcc` matcher that reads this plugin’s default lines.

Add a task to `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Ceedling: test all",
      "type": "shell",
      "command": "ceedling test:all",
      "problemMatcher": "$gcc",
      "group": "test"
    }
  ]
}
```

Without the C/C++ extension, give the task its own matcher:

```json
"problemMatcher": {
  "owner": "ceedling",
  "fileLocation": ["autoDetect", "${workspaceFolder}"],
  "pattern": {
    "regexp": "^(.*?):(\\d+):(\\d+):\\s+(warning|error):\\s+(.*)$",
    "file": 1,
    "line": 2,
    "column": 3,
    "severity": 4,
    "message": 5
  }
}
```

This matcher reads relative paths against the workspace folder. If your project
sits in a folder below the workspace’s root, use `:absolute_paths: TRUE` with
either matcher.

VS Code’s terminal also links `file:line:column` text. Lines printed by Ceedling
in the integrated terminal can be clicked without any task.

#### Ceedling for VS Code

The [Ceedling for VS Code][vscode-ceedling] extension runs your test suite in VS
Code’s _Testing_ view. It reads test results from the
[Test Suite Report Log Factory](report-tests-log-factory.md) plugin’s `cppunit`
report, so enable that plugin and report too (note that more recent versions of
the extension enable this for you).

The extension can also add this plugin’s lines to the _Problems_ view. Its `gcc`
preset scans only `$stderr`, and this report prints to `$stdout`. Give it patterns
of its own that scan `$stdout`:

```json
"ceedlingExplorer.problemMatching": {
  "mode": "patterns",
  "patterns": [
    {
      "scanStdout": true,
      "severity": "error",
      "filePrefix": "${projectPath}",
      "regexp": "^(.*):(\\d+):(\\d+):\\s+error:\\s+(.*)$",
      "file": 1,
      "line": 2,
      "column": 3,
      "message": 4
    },
    {
      "scanStdout": true,
      "severity": "warning",
      "filePrefix": "${projectPath}",
      "regexp": "^(.*):(\\d+):(\\d+):\\s+warning:\\s+(.*)$",
      "file": 1,
      "line": 2,
      "column": 3,
      "message": 4
    }
  ]
}
```

These patterns also scan `$stderr`, as the extension’s patterns do by default, so
compiler errors and warnings appear too.

[vscode-ceedling]: https://marketplace.visualstudio.com/items?itemName=throw-the-switch.vscode-ceedling

### CLion

CLion links tool output to files through an External Tool’s output filters. Its
filters find only absolute paths.

1. Set `:format: :clion` in your project file.
1. In _Settings_ ↳ _Tools_ ↳ _External Tools_, add a tool. Set _Program_ to `ceedling`,
   _Arguments_ to `test:all`, and _Working directory_ to `$ProjectFileDir$`.
1. Under the tool’s _Advanced Options_ ↳ _Output Filters_, add
   `$FILE_PATH$:$LINE$:$COLUMN$.*`.
1. Run the tool from _Tools_ ↳ _External Tools_. Each failed and ignored test’s location
   becomes a link in the Run window.

CLion’s built-in test runner does not support Unity. For code insight, the
[Compile Commands JSON DB](compile-commands-json-db.md) plugin writes a compilation
database that CLion can open as a project.

<br/><br/>
