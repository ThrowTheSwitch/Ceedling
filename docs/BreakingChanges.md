# 🌱 Ceedling Breaking Changes

These breaking changes are complemented by two other documents:

1. 🔊 **[Release Notes](ReleaseNotes.md)** for announcements, education, acknowledgements, and known issues.
1. 🪵 **[Changelog](Changelog.md)** for a structured list of additions, fixes, changes, and removals.

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

In place of `true` or `false`, `:use_test_preprocessing` now accepts:

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
    :executable: \"Code Cranker\"
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

