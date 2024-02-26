
# 💔 Breaking Changes for 0.32 Release Candidate

**Version:** 0.32 pre-release incremental build

**Date:** February 26, 2024

# Explicit `:paths` ↳ `:include` entries in the project file

The `:paths` ↳ `:include` entries in the project file must now be explicit and complete.

Eaerlier versions of Ceedling were rather accomodating when assembling the search paths for header files. The full list of directories was pulled from multiple `:paths` entries with de-duplication. If you had header files in your `:source` directories but did not explicitly list those directories in your `:include` paths, Ceedling would helpfully figure it out and use all the paths.

This behavior is no more. Why? For two interrelated reasons.

1. For large or complex projects, expansive header file search path lists can exceed command line maximum lengths on some platforms. An enforced, tailored set of search paths helps prevent this problem.
1. In order to support the desired behavior of `TEST_INCLUDE_PATH()` a concice set of “base” header file search paths is necessary. `:paths` ↳ `:include` is that base list.

Using 0.32 Ceedling with older project files can lead to errors when generating mocks or compiler errors on finding header files. Add all relevant header file search paths to the `:paths` ↳ `:include` project file entry to fix this problem.

# Format change for `:defines` in the project file

To better support per-test-executable configurations, the format of `:defines` has changed. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. A more logically named hierarchy differentiates `#define`s for test preprocessing, test compilation, and release compilation.
1. Previously, compilation symbols could be specified for a specific C file by name, but these symbols were only defined when compiling that specific file. Further, this matching was only against a file's full name. Now, pattern matching is also an option.
1. Filename matching for test compilation symbols happens against _only test file names_. More importantly, the configured symbols are applied in compilation of each C file that comprises a test executable. Each test executable is treated as a mini-project.

Symbols specified for release builds are applied to all files in the release build.

# Format change for `:flags` in the project file

To better support per-test-executable configurations, the format and function of `:flags` has changed somewhat. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. The format of the `:flags` configuration section is largely the same as in previous versions of Ceedling. However, the behavior of the matching rules is slightly different with more matching options.
1. Within the `:flags` ↳ `:test` context, all matching of file names is now limited to *_test files_*. For any test file name that matches, the specified flags are added to the named build step for _all files that comprise that test executable_. Previously, matching was against individual files (source, test, whatever), and flags were applied to only operations on that single file. Now, all files part of a test executable build get the same treatment as a mini-project.

Flags specified for release builds are applied to all files in the release build.

# `TEST_FILE()` ➡️ `TEST_SOURCE_FILE()`

The previously undocumented `TEST_FILE()` build directive macro (#796) available within test files has been renamed and is now officially documented. See earlier section on this.

# Quoted executables in tool definitions

While unusual, some executables have names with spaces. This is more common on Windows than Unix derivatives, particularly with proprietary compiler toolchains.

Originally, Ceedling would automatically add quotes around an executable containing a space when it built a full command line before passing it to a command shell.

This automagical help can break tools in certain contexts. For example, script-based executables in many Linux shells do not work (e.g. `"python path/script.py" --arg`).

Automatic quoting has been removed. If you need a quoted executable, simply explicitly include quotes in the appropriate string for your executable (this can occur in multiple locations throughout a Ceedling project). An example of a YAML tool defition follows:

```yaml
:tools:
  :funky_compiler:
    :executable: \"Code Cranker\"
```

# Build output directory structure changes

## Test builds

Each test is now treated as its own mini-project. Differentiating components of the same name that are a part of multiple test executables required further subdirectories in the build directory structure. Generated mocks, compiled object files, linked executables, and preprocessed output all end up one directory deeper than in previous versions of Ceedling. In each case, these files are found inside a subdirectory named for their containing test.

## Release builds

Release build object files were previously segregated by their source. The release build output directory had subdirectories `c/` and `asm/`. These subdirectories are no longer in use.

# Changes to global constants & accessors

Some global constant “collections” that were previously key elements of Ceedling have changed or gone away as the build pipeline is now able to process a configuration for each individual test executable in favor of for the entire suite.

Similarly, various global constant project file accessors have changed, specifically the values within the configuration file they point to as various configuration sections have changed format (examples above).

See the [official documentation](CeedlingPacket.md) on global constants & accessors for updated lists and information.

# `raw_output_report` plugin

This plugin (renamed -- see next section) no longer generates empty log files and no longer generates log files with _test_ and _pass_ in their filenames. Log files are now simply named `<test file>.raw.log`.

# Consolidation of plugins: `json_tests_report`, `xml_tests_report` & `junit_tests_report` ➡️ `report_tests_log_factory`

The individual `json_tests_report`, `xml_tests_report`, and `junit_tests_report` plugins are superseded by a single plugin `report_tests_log_factory` able to generate each or all of the previous test reports as well as user-defined tests reports. The new plugin requires a small amount of extra configuration the previous individual plugins did not. See the [`report_tests_log_factory` documentation](../plugins/report_tests_log_factory).

In addition, all references and naming connected to the previous `xml_tests_report` plugin have been updated to refer to _CppUnit_ rather than generic _XML_ as this is the actual format of the report that is processed.

# Built-in Plugin Name Changes

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

# `gcov` plugin coverage report generation name and behavior changes

The `gcov` plugin and its [documentation](../plugins/gcov) has been significantly revised. See [release notes](ReleaseNotes.md) for all the details.

The report generation task `utils:gcov` has been renamed and its behavior has been altered.

Coverage reports are now generated automatically unless the manual report generation task is enabled with a configuration option (the manual report generation option disables the automatc option). See below. If automatic report generation is disabled, the task `report:gcov` becomes available to trigger report generation (a `gcov:` task must be executed before `report:gcov` just as was the case with `utils:gcov`).

```yaml
:gcov:
  :report_task: TRUE
```


