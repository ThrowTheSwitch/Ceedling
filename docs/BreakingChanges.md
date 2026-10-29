# 🌱 Ceedling Breaking Changes

These breaking changes are complemented by three other documents:

1. 🔊 **[Release Notes](ReleaseNotes.md)** for announcements, education, and acknowledgements.
1. 🪵 **[Changelog](Changelog.md)** for a structured list of additions, fixes, changes, and removals.
1. 🐛 **[Known Issues](KnownIssues.md)** for a list of presently known problems and limitations.

A release has a section only if it breaks something. Each section lists what changed in that release alone, so upgrading across several releases means reading each section between them.

---

# [1.2.2] — Unreleased

## Test build output is organized by each test’s path from the project root

A test’s build output, results, and logs are organized by its name, and a test is now named by its path from the project root without its extension. Before 1.2.2, the name was its path below its test root, so two tests could mistakenly share one. `test/unit/test_calc.c` was named `unit/test_calc` and is now `test/unit/test_calc`. A test directly in its root gains a directory: `test/test_calc.c` logs to `build/artifacts/valgrind/test/test_calc.log`, not `build/artifacts/valgrind/test_calc.log`.

Update anything that reads per-test output by path:

1. Scripts that collect Valgrind, sanitizer, raw output, or gdb backtrace logs. A glob such as `build/artifacts/valgrind/*.log` no longer reaches them; use `build/artifacts/valgrind/**/*.log`.
1. Tools that read results, runners, or objects from `build/test/` directly.
1. TeamCity suite names, which now carry the same path (e.g. `test/TestUsartModel`).

The first build after upgrading rebuilds everything once. Run `ceedling clobber` to remove the output left in the old layout. Until then, any coverage reports also read the old coverage data.

## Build files are placed by each source’s path from the project root

An object, preprocessed file, or dependencies file now sits below its build directory at its source’s path from the project root. Before 1.2.2, it sat at the source’s path below its `:paths` root, or flat. In a test, `src/drivers/uart.c` builds to `build/test/out/<test name>/src/drivers/uart.o`, not `build/test/out/<test name>/drivers/uart.o`. A release builds it to `build/release/out/src/drivers/uart.o`. Each `..` in a path outside the project becomes `_up_`, and a file of the running Ceedling installation outside the project sits below `_ceedling_`. Mocks, runners, and vendored framework objects keep their places.

The first build after upgrading recompiles each moved object once. Run `ceedling clobber` to remove objects left in the old layout. Until then, coverage reports also include the old coverage data.

## A `-:` `:paths` entry removes the directories below it

A `-:` entry in `:paths` used to remove only the directory it named. It now also removes every directory below that directory. An additive entry naming one of those directories more closely keeps it, as `+:src/legacy/keep` does beside `-:src/legacy`. A project that relied on subdirectories surviving a `-:` entry must name them in entries of their own.

## A build root holding the project is refused

`:project` ↳ `:build_root` can no longer be empty, the project directory, or a directory above it. `clobber` empties the build root’s test and release trees, so with `:build_root: .` it deleted the project’s own `test/` directory. Configuration now stops with an error naming the problem.

A `:paths` or `:files` entry within the build root, such as one naming generated code in `build/gen`, still collects from it, with a warning. No entry collects from the directories Ceedling and its plugins create, such as `test/`, `release/`, `vendor/`, and `artifacts/` below the build root, or the mocks directory. A project that named one of them in `:paths` or `:files` loses those files from its collections.

## `-L` arguments name the directories `:paths` ↳ `:libraries` collects

Linker `-L` arguments used to repeat `:paths` ↳ `:libraries` entries exactly as written. They now name the directories those entries collect, as any `:paths` entry does. A glob names each directory it matches, a `-:` entry removes directories, and an entry that collects no existing directory adds no argument.

## `TEST_SOURCE_FILE()` entries are checked without test preprocessing

With `:project` ↳ `:use_test_preprocessor` set to `:none` or `:mocks`, a `TEST_SOURCE_FILE()` entry naming a file that doesn’t exist, or that isn’t a source file, was previously silently dropped. A build now stops with an error naming the entry and its test file, as it already did with test preprocessing.

Without test preprocessing, Ceedling reads these entries as text and does not evaluate `#if`. An entry inside an `#if` branch that is off is checked too, so it must name a real file.

## A project that selects another installation runs entirely in it

A project can select another Ceedling installation through `:project` ↳ `:which_ceedling`, the `WHICH_CEEDLING` environment variable, or a `vendor/ceedling/` copy. Before 1.2.2, the `ceedling` command you ran parsed the command line and loaded that installation’s application into its own process. Now that installation’s own launcher runs the command, in a new process.

1. The selected installation parses the command line itself. An older one rejects commands and options added after its release.
1. `new`, `example`, `examples`, `docs`, and `help` run in the installation `WHICH_CEEDLING` or a `vendor/ceedling/` copy selects, not in the `ceedling` command you ran. A `--local` copy carries no documentation bundle, so `docs` exports the documentation of the `ceedling` command you ran instead, with a notice.
1. Both sides of a hand-off log a notice at warning verbosity. It names both installations and their versions.
1. A project vendored by Ceedling 1.1.0 through 1.2.1 lacks Unity’s built-in mixins, so its copy cannot run on its own. The `ceedling` command you run stops with advice to re-vendor it with `ceedling upgrade`.

## `upgrade` no longer finds its source in `vendor/ceedling/`

`ceedling upgrade PATH` copies the Ceedling you run or the installation `WHICH_CEEDLING` names into the project at `PATH`. It no longer selects a `vendor/ceedling/` directory it finds in the working directory, which inside a `--local` project was the very copy it was replacing.

## `version` reads your project file

`ceedling version` reads your project file when one is available, as `build` does, and reports the installation the project selects. For a project that selects another installation, it lists `Ceedling Launcher =>` and `Ceedling App =>` instead of a single `Ceedling =>` line. A tool that parses `version` for the project’s Ceedling should read `Ceedling App =>` when present.

## Impacts on third-party plugins by file and path code moved to `lib/ceedling/filesystem/`

Ceedling plugin development currently makes no guarantees about the location and interface of internal Ceedling resources. And, it is unlikely that custom plugins would rely on the reorganized filesystem handling code to begin with.

Ceedling’s file and path code now sits in `lib/ceedling/filesystem/`. A plugin that requires one of these files directly must name its new path, such as `require 'ceedling/filesystem/file_path_utils'` in place of `require 'ceedling/file_path_utils'`. A require of an old path fails with a `LoadError`. Where an older Ceedling gem is installed, Ruby can instead load that gem’s copy of the file, and the build fails with an unrelated error such as `wrong number of arguments`. Plugins that reach these objects through `@ceedling[:file_wrapper]` and the like need no change. A plugin that names the new paths no longer loads in Ceedling 1.2.1 or earlier.

The moved files are `project_paths`, `build_subpath`, `path_spellings`, `path_exclusions`, `path_mirror`, `path_matcher`, `destination_collision`, `file_path_utils`, `file_path_collection_utils`, `file_finder`, `file_finder_helper`, `file_wrapper`, and `file_system_wrapper`.

---

# [1.2.0] — 2026-10-21

## Mocks included through a folder are named by that folder

`:cmock` ↳ `:mock_name_include_folder` is on by default. A mock included through a folder, such as `#include "drivers/uart/mock_config.h"`, now gets an include guard and `Init()`, `Verify()`, and `Destroy()` functions named by that folder (e.g. `drivers_uart_mock_config_Init()`). This lets one test file mock two same-named headers. The runner Ceedling generates calls the new names, so most projects need no change. A test or support file that calls a mock’s lifecycle functions directly, or references its include guard, must use the new names or set `:mock_name_include_folder` to `FALSE`.

## `-P` and `--no-line-commands` rejected with test preprocessing

Ceedling now refuses these preprocessor options at startup whenever test preprocessing is enabled. That is the case when `:project` ↳ `:use_test_preprocessor` is `:mocks`, `:tests`, or `:all`, or when Partials are enabled.

Both options strip the line markers Ceedling reads in preprocessor output to find `#include`s, mockable functions, and test cases. A project that used either one with test preprocessing already lost some of these, often without a clear error.

Remove the options from these places:

1. `:flags` ↳ `:test` ↳ `:preprocess` and `:compile`, and the same operations in plugin build contexts such as `:gcov`. Preprocessing uses `:compile` flags wherever no `:preprocess` flags apply.
1. The arguments of the `:test_file_full_preprocessor` and `:test_file_directives_only_preprocessor` tools.

If you need an option in `:compile` flags only, give `:preprocess` flags of their own without it.

## IDE console report lines are GCC diagnostics by default

`report_tests_ide_stdout` now lists each failed and ignored test the way GCC reports a problem. IDEs read these lines as errors and warnings without extra configuration.

```
test/TestModel.c:21:1: error: testInit: Expected 5 Was 4
```

The earlier lines looked like this:

```
test/TestModel.c:21:testInit: "Expected 5 Was 4"
```

A multi-line message no longer repeats the file, line, and test on every line. Its first line stays with the test’s location, and the rest follow indented. The Gcov, Bullseye, and Valgrind plugins print their test results through this plugin when it is enabled, so their lines change too.

A script, tool, or IDE configuration that matches the earlier lines must be updated. To keep the earlier lines, set the format to `:legacy`:

```YAML
:report_tests_ide_stdout:
  :format: :legacy
```

---

# [1.1.0] — 2026-07-16

## `--ruby-replacement` CLI flag to enable inline Ruby string expansion

As a security precaution, [inline Ruby string expansion][inline-ruby-string-expansion] within project configuration strings is now disabled by default. The feature still exists and functions, but it must be specifically enabled by the user at the command line each time Ceedling executes.

[inline-ruby-string-expansion]: https://docs.throwtheswitch.org/Ceedling/1.1.0/configuration/project-file/#inline-ruby-string-expansion

---

# [1.0.0] — 2025-01-01

## Explicit `:paths` ↳ `:include` entries in the project file

The `:paths` ↳ `:include` entries in the project file must now be explicit and complete.

Eaerlier versions of Ceedling were rather accomodating when assembling the search paths for header files. The full list of directories was pulled from multiple `:paths` entries with de-duplication. If you had header files in your `:source` directories but did not explicitly list those directories in your `:include` paths, Ceedling would helpfully figure it out and use all the paths.

This behavior is no more. Why? For two interrelated reasons.

1. For large or complex projects, expansive header file search path lists can exceed command line maximum lengths on some platforms. An enforced, tailored set of search paths helps prevent this problem.
1. In order to support the desired behavior of `TEST_INCLUDE_PATH()` a concice set of “base” header file search paths is necessary. `:paths` ↳ `:include` is that base list.

Using 1.0+ Ceedling with older project files can lead to errors when generating mocks or compiler errors on finding header files. Add all relevant header file search paths to the `:paths` ↳ `:include` project file entry to fix this problem.

## Format change for `:defines` in the project file

To better support per-test-executable configurations, the format of `:defines` has changed. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. A more logically named hierarchy differentiates `#define`s for test preprocessing, test compilation, and release compilation.
1. Previously, compilation symbols could be specified for a specific C file by name, but these symbols were only defined when compiling that specific file. Further, this matching was only against a file’s full name. Now, pattern matching is also an option.
1. Filename matching for test compilation symbols happens against _only test file names_. More importantly, the configured symbols are applied in compilation of each C file that comprises a test executable. Each test executable is treated as a mini-project.

Symbols specified for release builds are applied to all files in the release build.

## Format change for `:flags` in the project file

To better support per-test-executable configurations, the format and function of `:flags` has changed somewhat. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. The format of the `:flags` configuration section is largely the same as in previous versions of Ceedling. However, the behavior of the matching rules is slightly different with more matching options.
1. Within the `:flags` ↳ `:test` context, all matching of file names is now limited to *_test files_*. For any test file name that matches, the specified flags are added to the named build step for _all files that comprise that test executable_. Previously, matching was against individual files (source, test, whatever), and flags were applied to only operations on that single file. Now, all files part of a test executable build get the same treatment as a mini-project.

Flags specified for release builds are applied to all files in the release build.

## New `:project` ↳ `:use_test_preprocessor` configuration settings

Ceedling’s preprocessing features have been greatly improved. Preprocessing is now no longer all-or-nothing with a simple boolean value.

In place of `true` or `false`, `:use_test_preprocessor` now accepts:

* `:none` disables preprocessing (equivalent to previous `false` setting).
* `:all` enables preprpocessing for all mockable header files and test C files (equivalent to previous `true` setting).
* `:mocks` enables only preprocessing of header files that are to be mocked.
* `:tests` enables only preprocessing of your test files.

## `TEST_FILE()` ➡️ `TEST_SOURCE_FILE()`

The previously undocumented `TEST_FILE()` build directive macro (#796) available within test files has been renamed and is now officially documented.

## Preprocessing is unable to handle Unity’s `TEST_CASE()` and `TEST_RANGE()` and has limits for `TEST_INCLUDE_PATH()`

Ceedling’s preprocessing abilities have been nearly entirely rewritten. The one case Ceedling cannot yet handle is preprocessing test files that contain Unity’s parameterized test case macros.

`TEST_CASE()` and `TEST_RANGE()` are Unity macros that are positional in a file in relation to the test case functions they modify. While Ceedling's test preprocessing can preserve these macro calls, their position cannot be preserved.

You may want to wrap `TEST_INCLUDE_PATH()` in conditional compilation preprocessor statements (e.g. `#ifdef`). This will not work as you expect. This macro “marker” must be discovered at the beginning of a test build by Ceedling parsing a test file as plain text. Cyclical dependencies related to preprocessing prevent anything more sophisticated.

Note: `:project` ↳ `:use_test_preprocessor` is no longer a binary setting (`true`/`false`). Mockable header file preprocessing can now be enabled with a `:mocks` setting while test files are left untouched by preprocessing. This can allow test preprocessing in the common cases of sophtisticate mockable headers while Unity’s `TEST_CASE()` and `TEST_RANGE()` are utilized in a test file untouched by preprocessing.

## Quoted executables in tool definitions

While unusual, some executables have names with spaces. This is more common on Windows than Unix derivatives, particularly with proprietary compiler toolchains.

Originally, Ceedling would automatically add quotes around an executable containing a space when it built a full command line before passing it to a command shell.

This automagical help can break tools in certain contexts. For example, script-based executables in many Linux shells do not work (e.g. `"python path/script.py" --arg`).

Automatic quoting has been removed. If you need a quoted executable, simply explicitly include quotes in the appropriate string for your executable (this can occur in multiple locations throughout a Ceedling project). An example of a YAML tool defition follows:

```yaml
:tools:
  :funky_compiler:
    # YAML explicitly requires the outer quotation marks.
    # The command line requires the inner escaped quotation marks.
    :executable: "\"Code Cranker\""
```

## Build output directory structure changes

### Test builds

Each test is now treated as its own mini-project. Differentiating components of the same name that are a part of multiple test executables required further subdirectories in the build directory structure. Generated mocks, compiled object files, linked executables, and preprocessed output all end up one directory deeper than in previous versions of Ceedling. In each case, these files are found inside a subdirectory named for their containing test.

### Release builds

Release build object files were previously segregated by their source. The release build output directory had subdirectories `c/` and `asm/`. These subdirectories are no longer in use.

## Configuration defaults and configuration set up order

Ceedling’s previous handling of defaults and configuration processing order certainly worked, but it was not as proper as it could be. To oversimplify, default values were applied in an ordering that caused complications for advanced plugins and advanced users. This has been rectified. Default settings are now processed after all user configurations and plugins.

For some users and some custom plugins, the new ordering may cause unexpected results. The changes had no known impact on existing plugins and typical project configurations.

## Changes to global constants & accessors

Some global constant “collections” that were previously key elements of Ceedling have changed or gone away as the build pipeline is now able to process a configuration for each individual test executable in favor of for the entire suite.

Similarly, various global constant project file accessors have changed, specifically the values within the configuration file they point to as various configuration sections have changed format (examples above).

See the [official documentation](CeedlingPacket.md) on global constants & accessors for updated lists and information.

## `raw_output_report` plugin

This plugin (renamed -- see next section) no longer generates empty log files and no longer generates log files with _test_ and _pass_ in their filenames. Log files are now simply named `<test file>.raw.log`.

## Consolidation of test report generation plugins ➡️ `report_tests_log_factory`

The individual `json_tests_report`, `xml_tests_report`, and `junit_tests_report` plugins are superseded by a single plugin `report_tests_log_factory` able to generate each or all of the previous test reports as well as an HTML report and user-defined tests reports. The new plugin requires a small amount of extra configuration the previous individual plugins did not. See the [`report_tests_log_factory` documentation](../plugins/report_tests_log_factory).

In addition, all references and naming connected to the previous `xml_tests_report` plugin have been updated to refer to _CppUnit_ rather than generic _XML_ as this is the actual format of the report that is processed.

## Built-in Plugin Name Changes

The following plugin names must be updated in the `:plugins` ↳ `:enabled` list of your Ceedling project file.

This renaming was primarily enacted to more clearly organize and relate reporting-oriented plugins. Secondarily, some names were changed simply for greater clarity.

Some test report generation plugins were not simply renamed but superseded by a new plugin (see preceding section).

- `fake_function_framework` ➡️ `fff`
- `compile_commands_json` ➡️ `compile_commands_json_db`
- `json_tests_report`, `xml_tests_report` & `junit_tests_report` ➡️ `report_tests_log_factory`
- `raw_output_report` ➡️ `report_tests_raw_output_log`
- `stdout_gtestlike_tests_report` ➡️ `report_tests_gtestlike_stdout`
- `stdout_ide_tests_report` ➡️ `report_tests_ide_stdout`
- `stdout_pretty_tests_report` ➡️ `report_tests_pretty_stdout`   
- `stdout_teamcity_tests_report` ➡️ `report_tests_teamcity_stdout` 
- `warnings_report` ➡️ `report_build_warnings_log`
- `test_suite_reporter` ➡️ `report_tests_log_factory`

## `gcov` plugin coverage report generation name and behavior changes

The `gcov` plugin and its [documentation](../plugins/gcov) has been significantly revised. See [release notes](ReleaseNotes.md) for all the details.

The report generation task `utils:gcov` has been renamed and its behavior has been altered.

Coverage reports are now generated automatically unless the manual report generation task is enabled with a configuration option (the manual report generation option disables the automatc option). See below. If automatic report generation is disabled, the task `report:gcov` becomes available to trigger report generation (a `gcov:` task must be executed before `report:gcov` just as was the case with `utils:gcov`).

```yaml
:gcov:
  :report_task: TRUE
```

## Exit code handling (a.k.a. `:graceful_fail`)

Be default Ceedling terminates with an exit code of `1` when a build succeeds but unit tests fail.

A previously undocumented project configuration option `:graceful_fail` could force a Ceedling exit code of `0` upon test failures.

This configuration option has moved (and is now [documented](CeedlingPacket.md)).

Previously:
```yaml
:graceful_fail: TRUE
```

Now:
```yaml
:test_build:
  :graceful_fail: TRUE
```

## Project file environment variable name change `CEEDLING_MAIN_PROJECT_FILE` ➡️ `CEEDLING_PROJECT_FILE`

Options and support for loading a project configuration have expanded significantly, mostly notably with the addition of Mixins.

The environment variable option for pointing Ceedling to a project file other than _project.yml_ in your working directory has been renamed `CEEDLING_MAIN_PROJECT_FILE` ➡️ `CEEDLING_PROJECT_FILE`.

In addition, a previously undocumented feature for merging a second configuration via environment variable `CEEDLING_USER_PROJECT_FILE` has been removed. This feature has been superseded by the new Mixins functionality.

Thorough documentation on Mixins and the new options for loading a project configuration can be found in _[CeedlingPacket](CeedlingPacket.md))_.

## Replaced `options:` files, environment project specifications, and nested project files with comprehensive `mixins` feature

The following features have all been removed from Ceedling's functionality. No need to worry, though. The new `mixins` feature can handle all the situations these features previously supported, and much more. Check out the [documentation](CeedlingPacket.md) for more detail.

 - `options:blah.yml` command-line options (see `--mixin` command line option)
 - The corresponding `options_paths:` key in the project.yml file no longer has any effect. (see `:mixins:` ➡️ `:load_paths:` project.yml specification)
 - The `:import:` section of the `project.yml` has been replaced (see `:mixins:` ➡️ `:enabled:` section)
 - `CEEDLING_PROJECT_FILE` environment variable (see `CEEDLING_MIXIN_#` specification)
 - `CEEDLING_SER_FILE` environment variable (see `CEEDLING_MIXIN_#` specification)

## Tool definition inline Ruby evaluation replacement removed (inline Ruby string expansion remains)

Reaching back to the earliest days of Ceedling, tool definitions supported two slightly different string replacement options that executed at different points in a build’s lifetime. Yeah. It was maybe not great.

Support for `{...}` Ruby evaluation in tool definitions has been removed.

Support for `#{...}` Ruby string expansion in tool definitions remains and is now evaluated each time a tool is executed during a build.

## Command Hooks plugin configuration change

In previous versions of Ceedling, the Command Hooks plugin associated tools and hooks by a naming convention within the top-level `:tools` section of your project configuration. This required some semi-ugly tool names and could lead to a rather unwieldy `:tools` list. Further, this convention also limited a hook to an association with only a single tool.

Hooks are now enabled within a top-level `:command_hooks` section in your project configuration. Each hook key in this configuration block can now support one or more tools organized beneath it. As such, each hook can execute one or more tools.

## Subprojects plugin replaced

The `subprojects` plugin has been completely replaced by the more-powerful `dependencies` plugin. To retain your previous functionality, you need to do a little reorganizing in your `project.yml` file. Obviously the `:subprojects` section is now called `:dependencies`. The collection of `:paths` is now `:deps`. We'll have a little more organizing to do once we're inside that section as well. Your `:source` is now organized in `:paths` ↳ `:source` and, since you're not fetching it form another project, the `:fetch` ↳ `:method` should be set to `:none`. The `:build_root` now becomes `:paths` ↳ `:build`. You'll also need to specify the name of the library produced under `:artifacts` ↳ `:static_libraries`.

For example:

```
:subprojects:  
  :paths:
   - :name: libprojectA
     :source:
       - ./subprojectA/
     :include:
       - ./subprojectA/inc
     :build_root: ./subprojectA/build/dir
     :defines: 
       - DEFINE_JUST_FOR_THIS_FILE
       - AND_ANOTHER
```

The above subproject definition will now look like the following:

```
:dependencies:
  :deps:
    - :name: Project A
      :paths:
        :fetch:    ./subprojectA/
        :source:   ./subprojectA/
        :build:    ./subprojectA/build/dir
        :artifact: ./subprojectA/build/dir
      :fetch:
        :method: :none
      :environment: []
      :build:
        - :build_lib
      :artifacts:
        :static_libraries:
          - libprojectA.a
        :dynamic_libraries: []
        :includes: 
          - ../subprojectA/subprojectA.h
      :defines: 
        - DEFINE_JUST_FOR_THIS_FILE
        - AND_ANOTHER
```

## Undocumented `:project` ↳ `:debug` has been removed

This project setting existed from Ceedling’s earliest days and was a crude stand-in for command line debug verbosity handling.

It has been removed as it was rarely if ever utilized and needlessly complicated internal mechanisms for verbosity handling and project validation.

