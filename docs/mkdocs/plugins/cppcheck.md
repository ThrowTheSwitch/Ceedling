# Cppcheck

Adds Ceedling tasks to execute Cppcheck static analysis, helping detect
undefined behavior, dangerous code patterns, and style issues across your
project or individual files.

## Plugin overview

The Cppcheck plugin integrates [Cppcheck](https://cppcheck.sourceforge.io)
static analysis into Ceedling, facilitating automated code quality checks as
part of your development workflow. It provides two analysis modes:

- **Whole project analysis**: By running `ceedling cppcheck:all`, all project
source files will be analyzed with all checks enabled (`--enable=all`) and
configurable reports can be generated in multiple formats.
- **Single file analysis**: By running `ceedling cppcheck:<filename>`, an
individual source file will be analyzed using the checks configured in the
`:enable_checks` list (defaults to `style`).

The plugin supports extensive Cppcheck configuration options such as platform,
language standard, preprocessor defines, include/exclude paths, and suppression
management. It also integrates with advanced features like MISRA addons, custom
check levels, library configuration files, and regular expression rules. All of
these can be configured in your `project.yml` file.

The plugin can produce reports in HTML, SARIF, text, and XML (v2 and v3)
formats, all stored under the build artifacts directory.

It also suppoprts using a project file (such as `compile_commands.json` or a
Cppcheck GUI project), in which case, the plugin delegates source and include
path discovery to Cppcheck rather than using Ceedling's own file collection.

## Setup

Enable the plugin by adding `cppcheck` to the enabled plugins list in your
`project.yml` file:

```yaml
:plugins:
  :enabled:
    - cppcheck
```

## Configuration

Add `cppcheck` section to your `project.yml` specifying configuration options.
e.g:

```yaml
:cppcheck:
  :reports:
    - html
  :addons:
    - misra
```

### Reports

Four types of reports are available:

- html
- sarif
- text
- xml (v2 and v3)

They can be enabled by listing them on the `:reports` list:

```yaml
:cppcheck:
  :reports:
    - text
    - html
```

#### HTML

HTML title can be configured:

```yaml
:cppcheck:
  :html_title: Awesome Project
```

*Notes:*

- This report requires the `cppcheck-htmlreport` tool to be available.
- This report implies the `xml` report.

#### Sarif

Artifact file can be configured:

```yaml
:cppcheck:
  :sarif_artifact_filename: CppcheckResults.sarif
```

#### Text

Artifact file and output format can be configured:

```yaml
:cppcheck:
  :text_artifact_filename: CppcheckResults.txt
  :template: gcc
```

`:template` can be any of the ones included with Cppcheck or custom format string.

#### XML

Artifact file and XML version can be configured:

```yaml
:cppcheck:
  :xml_artifact_filename: CppcheckResults.xml
  :xml_report_version: 2
```

### Import project file

You can import some project files and build configurations into Cppcheck.
Some of compatible files are:

- Cppcheck GUI project (\*.cppcheck)
- Compile Commands (compile_commands.json)
- Visual Studio projects (\*.vcxproj, \*.sln)

```yaml
:cppcheck:
  :project: path/to/compile_commands.json
```

*Note: If configured, Cppcheck won't look for sources and includes paths from*
*_Ceedling_ configuration files.*

### Preprocessor defines

#### Define

```yaml
:cppcheck:
  :defines:
    - A
    - B
    - C=1
```

#### Undefine

```yaml
:cppcheck:
  :undefines:
    - A
    - B
    - C
```

*Note: By default `TEST` is undefined so the analysis is performed against production code.*

### Includes

Force inclusion of files before checked files.

```yaml
:cppcheck:
  :includes:
    - file1.h
    - file2.h
```

### Excludes

Exclude files from the analysis.

```yaml
:cppcheck:
  :excludes:
    - file1.c
    - file2.c
```

### Platform

Specify platform to use for the analysis, can be any of the ones included with
Cppcheck, e.g.: unix64, or the path of the platform XML file.

```yaml
:cppcheck:
  :platform: unix64
```

### Standard

Specify C/C++ language standard.

```yaml
:cppcheck:
  :standard: c99
```

### Check level

Specify the check level to be used.

- *normal*
- *exhaustive*

```yaml
:cppcheck:
  :check_level: exhaustive
```

### Addons

Addons to be run.

```yaml
:cppcheck:
  :addons:
    - misra
    - path/to/addon.py
```

#### MISRA with rule texts file

Locate your rules text file or copy it to your project.
e.g.: `<your-project>/misra.txt` and create the addon file `misra.json` inside
your project:

##### **`misra.json`**
```json
{
	"script": "misra",
	"args": ["--rule-texts=misra.txt"]
}
```

Enable the addon:

```yaml
:cppcheck:
  :addons:
    - misra.json
```

### Checks

Enable additional checks.
Default is *style*.

```yaml
:cppcheck:
  :enable_checks:
    - performance
    - portability
```

*Note: These are only used for single file analysis.*
*Whole project analysis always enable all checks.*

Disable individual checks:

```yaml
:cppcheck:
  :disable_checks:
    - style
    - information
```

### Suppressions

#### Inline

Inline suppressions are disabled by default, they can be enabled with:

```yaml
:cppcheck:
  :inline_suppressions: true
```

#### List files

Suppressions files can be used by giving the search paths and/or files in the
`:paths` and `:files` sections of  your `project.yml` respectively.
e.g.:

```yaml
:paths:
  :cppcheck:
    - suppressions/
    - source/*/suppressions/

:files:
  :cppcheck:
    - suppressions.xml
```

Both XML and text files are supported, and for the latter, the file extension
can be configured. The default is `.txt`.
e.g.:

```yaml
:extension:
  :cppcheck: .txt
```

The files that will ultimately be used can be verified with:

```shell
$ ceedling files:cppcheck
```

#### Command line

Command line suppressions can also be added:

```yaml
:cppcheck:
  :suppressions:
    - memleak:src/file1.cpp
    - exceptNew:src/file1.cpp
```

### Library configuration

Add library configuration files:

```yaml
:cppcheck:
  :libraries:
    - lib1.cfg
    - lib2.cfg
```

### Rules

Regular expression rules:

```yaml
:cppcheck:
  :rules:
    - if \( p \) { free \( p \) ; }
```

### Extra options

For things not covered above, add extra command line options:

```yaml
:cppcheck:
  :options:
    - --max-configs=<limit>
    - --suppressions-list=<file>
```

## Usage

### Analyze whole project

Run analysis for all project sources:

```shell
$ ceedling cppcheck:all
```

*Note: Analysis is run with* all *checks enabled.*

### Analyze single file

Run analysis for single source file:

```shell
$ ceedling cppcheck:<filename>
```

*Note: Analysis will run with the checks in [`:enable_checks`](#checks) list enabled.*
