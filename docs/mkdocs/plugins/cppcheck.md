# Cppcheck

Adds Ceedling tasks to run [Cppcheck] static analysis. Cppcheck finds undefined
behavior, dangerous code patterns, and style issues across your project or in a
single file, without running your code.

!!! note
    A `cppcheck:` task analyzes source. It builds and runs nothing, so it is not
    a [delta build](../getting-started/builds.md) and shares no state with your
    `test:` builds.

---

## Plugin overview

The Cppcheck plugin runs [Cppcheck] over your project and writes reports to the
build artifacts directory. It provides two analysis modes.

- **Whole project analysis**: `ceedling cppcheck:all` analyzes all project
  sources with every check enabled (`--enable=all`) and writes the reports you
  configure.
- **Single file analysis**: `ceedling cppcheck:<filename>` analyzes one source
  file using the checks in [`:enable_checks:`](#enable_checks), and prints
  findings to the console.

Reports are available in HTML, SARIF, text, and XML. The plugin also exposes
most of Cppcheck's configuration surface, including platform, language
standard, preprocessor defines, include and exclude paths, addons such as
MISRA, library configuration files, regular expression rules, and suppression
management.

A build can be failed on findings. See [`:fail_build:`](#fail_build).

!!! note "Analysis runs once per report format"
    Cppcheck emits one format per invocation, so each entry in
    [`:reports:`](#reports) costs its own full analysis pass. Cppcheck's own
    `--cppcheck-build-dir` cache reduces the cost of passes after the first.

## Installation & set up

### Installation

You have several options for getting the `cppcheck` tool working on your
system, including one readymade option.

#### Linux package manager

```shell
sudo apt-get install cppcheck   # Debian / Ubuntu
sudo dnf install cppcheck       # Fedora / RHEL
```

#### macOS

```shell
brew install cppcheck
```

#### Windows

```shell
choco install cppcheck
```

Alternatively, use the installer from [Cppcheck's site][cppcheck-download].

#### Build from source

Source releases are available from [Cppcheck's GitHub releases][cppcheck-releases].

#### _MadScienceLab_ Docker images

Fully packaged [_MadScienceLab_ Docker images][docker-hub] containing Ruby,
Ceedling, the GCC toolchain, and more are available. The `-plugins` variants
of the images come with all of Ceedling's plugin tools preinstalled.

!!! note "HTML reports need a second tool"
    The [`html`](#reports) report is produced by `cppcheck-htmlreport`, which
    ships alongside Cppcheck in most distributions. It is optional. Every other
    report format needs only `cppcheck` itself.

### Enable the plugin

Enable the plugin by adding `cppcheck` to the enabled plugins list in your
project configuration:

```yaml
:plugins:
  :enabled:
    - cppcheck
```

Enabling the plugin alone requires no Cppcheck installation. The executable is
only needed when a `cppcheck:` task actually runs.

## Configuration

All settings live in a top-level `:cppcheck` section of your project file.

```yaml
:cppcheck:
  :reports:
    - html
  :addons:
    - misra
```

### `:reports:`

The report formats to produce. Each entry costs its own analysis pass.

* `html` — Browsable HTML. Requires `cppcheck-htmlreport` and implies `xml`.
* `sarif` — SARIF, consumed by many code-scanning dashboards.
* `text` — Plain text.
* `xml` — Cppcheck's own XML schema.

```yaml
:cppcheck:
  :reports:
    - text
    - html
```

**Default:** `[]` (no reports, so `cppcheck:all` analyzes nothing and says so)

### `:fail_build:`

When `true`, findings matching [`:fail_build_severities:`](#fail_build_severities)
fail the build. Enabling this implies the `xml` report, because findings are
counted from Cppcheck's own XML output.

```yaml
:cppcheck:
  :fail_build: true
```

**Default:** `false`

Cppcheck exits successfully even when it finds defects, so without this setting
a `cppcheck:all` run can never fail a CI build.

### `:fail_build_severities:`

Which finding severities fail the build when
[`:fail_build:`](#fail_build) is enabled. Valid values are `error`, `warning`,
`style`, `performance`, `portability`, and `information`. An unrecognized value
is rejected when the plugin loads.

```yaml
:cppcheck:
  :fail_build_severities:
    - error
    - warning
```

**Default:** `[error]`

!!! tip "Why not every severity by default"
    Whole project analysis always runs with `--enable=all`, so a typical run
    reports many `style` and `information` findings. Failing on all of them
    would make this setting impractical on most projects.

### `:html_title:`

Title shown in the HTML report.

```yaml
:cppcheck:
  :html_title: Awesome Project
```

**Default:** unset

### `:sarif_artifact_filename:`

Filename for the SARIF report.

```yaml
:cppcheck:
  :sarif_artifact_filename: CppcheckResults.sarif
```

**Default:** `CppcheckReport.sarif`

### `:text_artifact_filename:`

Filename for the text report.

```yaml
:cppcheck:
  :text_artifact_filename: CppcheckResults.txt
```

**Default:** `CppcheckReport.txt`

### `:template:`

Output format for the text report. Accepts any template name Cppcheck ships
with, such as `gcc`, or a custom format string.

```yaml
:cppcheck:
  :template: gcc
```

**Default:** unset (Cppcheck's own default)

### `:xml_artifact_filename:`

Filename for the XML report.

```yaml
:cppcheck:
  :xml_artifact_filename: CppcheckResults.xml
```

**Default:** `CppcheckReport.xml`

### `:xml_report_version:`

Cppcheck XML schema version. Accepts `2` or `3`.

```yaml
:cppcheck:
  :xml_report_version: 3
```

**Default:** `2`

!!! warning "Version 3 requires a newer Cppcheck"
    Older Cppcheck releases reject `--xml-version=3` outright and fail the
    build. Version 2 is accepted by every release. Both versions carry the same
    severity information, so this plugin's finding counts work with either.

### `:project:`

Import a project file and let Cppcheck discover sources and include paths
itself. Compatible files include Cppcheck GUI projects (`*.cppcheck`),
compilation databases (`compile_commands.json`), and Visual Studio projects
(`*.vcxproj`, `*.sln`).

```yaml
:cppcheck:
  :project: path/to/compile_commands.json
```

**Default:** unset

!!! note "What `:project:` does and does not replace"
    Setting this stops the plugin passing Ceedling's own source and include
    path collections. Every other setting in this section still applies.
    `:defines:`, `:includes:`, `:excludes:`, `:suppressions:`, `:addons:`, and
    the rest are all still added to the command line.

### `:defines:`

Preprocessor symbols to define.

```yaml
:cppcheck:
  :defines:
    - A
    - B
    - C=1
```

**Default:** `[]`

### `:undefines:`

Preprocessor symbols to undefine.

```yaml
:cppcheck:
  :undefines:
    - A
    - B
```

**Default:** `[TEST]`

`TEST` is undefined by default so analysis runs against production code rather
than test builds.

### `:includes:`

Files force-included ahead of each analyzed file.

```yaml
:cppcheck:
  :includes:
    - file1.h
    - file2.h
```

**Default:** `[]`

### `:excludes:`

Files excluded from analysis.

```yaml
:cppcheck:
  :excludes:
    - file1.c
    - file2.c
```

**Default:** `[]`

### `:platform:`

Platform to analyze for. Accepts any platform Cppcheck ships with, such as
`unix64`, or the path to a platform XML file.

```yaml
:cppcheck:
  :platform: unix64
```

**Default:** unset

### `:standard:`

C or C++ language standard.

```yaml
:cppcheck:
  :standard: c99
```

**Default:** unset

### `:check_level:`

Analysis depth. Accepts the levels your Cppcheck supports, commonly `normal`
and `exhaustive`.

```yaml
:cppcheck:
  :check_level: exhaustive
```

**Default:** unset

### `:addons:`

Addons to run. Entries may be built-in addon names or paths to addon scripts
and JSON addon configurations.

```yaml
:cppcheck:
  :addons:
    - misra
    - path/to/addon.py
```

**Default:** `[]`

MISRA needs a rule texts file, which is not distributed with Cppcheck. Place
your copy in the project, for example at `misra.txt`, then create an addon
configuration naming it:

```json
{
	"script": "misra",
	"args": ["--rule-texts=misra.txt"]
}
```

Enable that configuration rather than the bare addon name:

```yaml
:cppcheck:
  :addons:
    - misra.json
```

### `:enable_checks:`

Additional checks enabled for single file analysis.

```yaml
:cppcheck:
  :enable_checks:
    - performance
    - portability
```

**Default:** `[style]`

!!! note "Single file analysis only"
    Whole project analysis always enables every check with `--enable=all`, so
    this setting does not affect `cppcheck:all`.

### `:disable_checks:`

Checks to disable. Applies to both analysis modes.

```yaml
:cppcheck:
  :disable_checks:
    - style
    - information
```

**Default:** `[]`

### `:inline_suppressions:`

Honor suppression comments written inline in source.

```yaml
:cppcheck:
  :inline_suppressions: true
```

**Default:** `false`

### `:suppressions:`

Suppressions given directly on the command line.

```yaml
:cppcheck:
  :suppressions:
    - memleak:src/file1.c
    - exceptNew:src/file1.c
```

**Default:** `[]`

Suppression *files* are collected separately, through Ceedling's path and file
collections rather than this list:

```yaml
:paths:
  :cppcheck:
    - suppressions/
    - source/*/suppressions/

:files:
  :cppcheck:
    - suppressions.xml
```

Both XML and text suppression files are supported. The extension used to find
text suppression files is configurable:

```yaml
:extension:
  :cppcheck: .txt
```

Confirm which files were collected with the
[`files:cppcheck`](#list-suppression-files) task.

### `:libraries:`

Library configuration files.

```yaml
:cppcheck:
  :libraries:
    - lib1.cfg
    - lib2.cfg
```

**Default:** `[]`

### `:rules:`

Regular expression rules.

```yaml
:cppcheck:
  :rules:
    - if \( p \) { free \( p \) ; }
```

**Default:** `[]`

### `:options:`

Raw command line arguments passed straight through to Cppcheck. This is the
escape hatch for anything the settings above do not cover.

```yaml
:cppcheck:
  :options:
    - --max-configs=<limit>
    - --suppressions-list=<file>
```

**Default:** `[]`

## Usage

### Analyze whole project

Run analysis across all project sources:

```shell
$ ceedling cppcheck:all
```

Every check is enabled for this mode. Configure at least one entry in
[`:reports:`](#reports) or enable [`:fail_build:`](#fail_build), or this task
has nothing to produce and says so.

### Analyze single file

Run analysis for one source file, by filename with no path:

```shell
$ ceedling cppcheck:example_file.c
```

Findings print to the console. This mode uses the checks in
[`:enable_checks:`](#enable_checks).

### List suppression files

Show which suppression files were collected from your configured paths and
files:

```shell
$ ceedling files:cppcheck
```

This task needs no Cppcheck installation.

## Artifacts

Reports are written to `build/artifacts/cppcheck/`:

| Report | Path |
|--------|------|
| HTML | `build/artifacts/cppcheck/html/index.html` |
| SARIF | `build/artifacts/cppcheck/CppcheckReport.sarif` |
| Text | `build/artifacts/cppcheck/CppcheckReport.txt` |
| XML | `build/artifacts/cppcheck/CppcheckReport.xml` |

Filenames other than the HTML directory are configurable. See the
`*_artifact_filename` settings above.

These artifacts are included in `ceedling clean` targets.

## Interpreting results

Whole project analysis prints a per-severity tally after it runs:

```
Cppcheck findings: 1 error, 2 information, 2 style
```

Cppcheck assigns every finding one of six severities.

| Severity | Meaning |
|----------|---------|
| `error` | A definite defect, such as a double free or buffer overrun |
| `warning` | Likely a defect, worth review |
| `style` | Stylistic issue, including unused code |
| `performance` | Code that is correct but avoidably slow |
| `portability` | Behavior that differs across compilers or platforms |
| `information` | Notes about the analysis itself, such as missing includes |

Only `error` fails a build by default. Widen that with
[`:fail_build_severities:`](#fail_build_severities).

For finding-by-finding detail, open a configured report. The text report is
easiest to read at the terminal:

```shell
$ cat build/artifacts/cppcheck/CppcheckReport.txt
```

See [Cppcheck's manual][cppcheck-manual] for what each check means and how to
suppress findings you have reviewed.

[Cppcheck]:           https://cppcheck.sourceforge.io
[cppcheck-download]:  https://cppcheck.sourceforge.io/#download
[cppcheck-releases]:  https://github.com/danmar/cppcheck/releases
[cppcheck-manual]:    https://cppcheck.sourceforge.io/manual.pdf
[docker-hub]:         https://hub.docker.com/repository/docker/throwtheswitch/

<br/><br/>
