# Build Warnings Log

Capture build process warnings from command line tools to a plain text log file.

## Overview

This plugin collects the warnings that command line tools print as a build preprocesses,
compiles, and links, and writes them to a plain text log file when the build ends. Each
build context — `test`, `release`, or a plugin's build such as `gcov` — gets its own log
in `<build root>/artifacts/<context>/`, written even when the build ends in an error.

Warnings from Ceedling itself or from code generation do not appear in these logs; only
the output of the preprocessing, compilation, and linking tools is collected.

Each warning keeps the lines that explain it. GCC and Clang print a warning with its
source line and a caret marking the spot, often after an `In function` or
`In file included from` line, and the log holds all of it:

```text
a.c: In function 'a':
a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]
    2 | int a( void ) { int spare; return 0; }
      |                     ^~~~~
```

Each distinct warning is logged once per build context. A warning in a header that many
files include appears once, with the include chain of the first file that reported it.

Output from other toolchains, whose warnings do not follow GCC's format, is collected a
line at a time.

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
| `:filename` | Name of each log file | `warnings.log` |
| `:patterns` | Regular expressions that find warnings, replacing the default | any line mentioning “warning” |
| `:excludes` | Regular expressions that drop collected warnings | none |

### Filename

```yaml
:report_build_warnings_log:
  :filename: more_better_filename.ext
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
anywhere in the warning's text, context lines included. Use it to quiet warnings you have
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
