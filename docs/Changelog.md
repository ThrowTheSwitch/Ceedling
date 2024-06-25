# 🌱 Ceedling Changelog

This format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This changelog is complemented by two other documents:

1. 🔊 **[Release Notes](ReleaseNotes.md)** for announcements, education, acknowledgements, and known issues.
1. 💔 **[Breaking Changes](BreakingChanges.md)** for a list of impacts to existing Ceedling projects.

---

# [1.0.0 pre-release] — 2024-06-19

## 🌟 Added

### Parallel execution of build steps

As was explained in the _[Highlights](#-Highlights)_, Ceedling can now run its internal tasks in parallel and take full advantage of your build system’s resources. Even lacking various optimizations (see _[Known Issues](#-Known-Issues)_) builds are now often quite speedy.

Enabling this speedup requires either or both of two simple configuration settings. See Ceedling’s [documentation](CeedlingPacket.md) for `:project` ↳ `:compile_threads` and `:project` ↳ `:test_threads`.

### A proper command line

Ceedling now offers a full command line interface with rich help, useful order-independent option flags, and more.

The existing `new`, `upgrade`, `example`, and `exampples` commands remain but have been improved. For those commands that support it, you may now specify the project file to load (see new, related mixins feature discussed elsewhere), log file to write to, exit code handling behavior, and more from the command line.

Try `ceedling help` and then `ceedling help <command>` to get started.

See the _[Release Notes](ReleaseNotes.md)_ and _[CeedlingPacket](CeedlingPacket.md)_ for more on the new and improved command line.

### `TEST_INCLUDE_PATH(...)` & `TEST_SOURCE_FILE(...)`

Issue [#743](https://github.com/ThrowTheSwitch/Ceedling/issues/743)

Using what we are calling build directive macros, you can now provide Ceedling certain configuration details from inside a test file.

See the [documentation](CeedlingPacket.md) discussion on include paths, Ceedling conventions, and these macros to understand all the details.

_Note:_ Ceedling is not yet capable of preserving build directive macros through preprocessing of test files. If, for example, you wrap these macros in
        conditional compilation preprocessing statements, they will not work as you expect.

#### `TEST_INCLUDE_PATH(...)` 

In short, `TEST_INCLUDE_PATH()` allows you to add a header file search path to the build of the test executable in which it is found. This can mean much shorter compilation command lines and good flexibility for complicated projects.

#### `TEST_SOURCE_FILE(...)`

In short, `TEST_SOURCE_FILE()` allows you to be explicit as to which source C files should be compiled and linked into a test executable. Sometimes Ceedling’s convention for matching source files with test files by way of `#include`d header files does not meet the need. This solves the problems of those scenarios.

### Mixins for modifying your configuration

Thorough documentation on Mixins can be found in _[CeedlingPacket](CeedlingPacket.md)_.

### Additional options for loading a base configuration from a project file

Once upon a time, you could load a project configuration in just two simple ways — _project.yml_ in your working directory and an environment variable pointing to a different file. Those days are over.

You may now:

* Load your project configuration from a filepath provided at the command line.
* Load your project configuration from an environment variable hoding a filepath.
* Load your project configuration from the default _project.yml_ in your working directory.
* Modify your configuration with Mixins loaded from your project file, environment variables, and/or from the command line.

All the options for loading and modifying a project configuration are thoroughly documented in _[CeedlingPacket](CeedlingPacket.md))_.

### Broader crash detection in test suites and new backtrace abilities

Previously Ceedling had a limited ability to detect and report segmentation faults and primarily on Unix-like platforms. This has been expanded and improved to crash detection more broadly. Invalid memory accesses, stack overflows, heap errors, and branching problems can all lead to crashed test executables. Ceedling is now able to detect these across platforms and report on them appropriately.

Ceedling defaults to executing this new behavior. Optionally, it can be disabled or its reporting enhanced further by enabling the use of `gdb`.

See _[CeedlingPacket](CeedlingPacket.md))_ for the new `:project` ↳ `:use_backtrace` feature to control how much detail is extracted from a crashed test executable to help you find the cause.

### More better `:flags` handling

Issue [#43](https://github.com/ThrowTheSwitch/Ceedling/issues/43)

Each test executable is now built as a mini project. Using improved `:flags` handling and an updated section format within Ceedling’s project configuration, you have much better options for specifying flags presented to the various tools within your build, particulary within test builds.

### More better `:defines` handling

Each test executable is now built as a mini project. Using improved `:defines` handling and an updated section format within Ceedling’s project configuration, you have much better options for specifying symbols used in your builds' compilation steps, particulary within test builds.

One powerful new feature is the ability to test the same source file built differently for different tests. Imagine a source file has three different conditional compilation sections. You can now write unit tests for each of those sections without complicated gymnastics to cause your test suite to build and run properly.

### Inline Ruby string expansion for `:flags` and `:defines` configuration entries

Inline Ruby string expansion has been, well, expanded for use in `:flags` and `:defines` entries to complement existing such functionality in `:environment`, `:paths`, `:tools`, etc.

The previously distributed documentation for inline Ruby string expansion has been collected into a single subsection within the project file documentation and improved.

### `report_tests_log_factory` plugin

This new plugin consolidates a handful of previously discrete report gernation plugins into a single plugin that also enables low-code, custom, end-user created reports.

The output of these prior plugins are now simply configuration options for this new plugin:

1. `junit_tests_report`
1. `json_tests_report`
1. `xml_tests_report`

This new plugin also includes the option to generate an HTML report (see next section).

### HTML tests report

A community member submitted an [HTML report generation plugin](https://github.com/ThrowTheSwitch/Ceedling/pull/756/) that was not officially released before 0.32. It has been absorbed into the new `report_tests_log_factory` plugin (see previous section).

### Improved Segfault Handling

Segmentation faults are now reported as failures instead of an error with as much detail as possible. See the project configuration file documentation on `:project` ↳ `:use_backtrace` for more!

### Pretty logging output

Ceedling logging now optionally includes emoji and nice Unicode characters. Ceedling will attempt to determine if your platform supports it. You can use the environment variable `CEEDLING_DECORATORS` to force the feature on or off. See the documentation for logging decorators in _[CeedlingPacket](CeedlingPacket.md)_.

### Vendored license files

The application commands `ceedling new` and `ceedling upgrade` at the command line provide project creation and management functions. Optionally, these commands can vendor tools and libraries locally alongside your project. These vendoring options now include license files along with the source of the vendored tools and libraries.

## 💪 Fixed

### `:paths` and `:files` handling bug fixes and clarification

Most project configurations are relatively simple, and Ceedling’s features for collecting paths worked fine enough. However, bugs and ambiguities lurked. Further, insufficient validation left users resorting to old fashioned trial-and-error troubleshooting.

Much glorious filepath and pathfile handling now abounds:

* The purpose and use of `:paths` and `:files` has been clarified in both code and documentation. `:paths` are directory-oriented while `:files` are filepath-oriented.
* [Documentation](CeedlingPacket.md) is now accurate and complete.
* Path handling edge cases have been properly resolved (`./foo/bar` is the same as `foo/bar` but was not always processed as such).
* Matching globs were advertised in the documentation (erroneously, incidentally) but lacked full programmatic support.
* Ceedling now tells you if your matching patterns don't work. Unfortunately, all Ceedling can determine is if a particular pattern yielded 0 results.

### Bug fixes for command line build tasks `files:header` and `files:support`

Longstanding bugs produced duplicate and sometimes incorrect lists of header files. Similarly, support file lists were not properly expanded from globs. Both of these problems have been fixed. The `files:header` command line task has replaced the `files:include` task.

### Dashed filename handling bug fix

Issue [#780](https://github.com/ThrowTheSwitch/Ceedling/issues/780)

In certain combinations of Ceedling features, a dash in a C filename could cause Ceedling to exit with an exception. This has been fixed.

### Source filename extension handling bug fix

Issue [#110](https://github.com/ThrowTheSwitch/Ceedling/issues/110)

Ceedling has long had the ability to configure a source filename extension other than `.c` (`:extension` ↳ `:source`). However, in most circumstances this ability would lead to broken builds. Regardless of user-provided source files and filename extenion settings, Ceedling’s supporting frameworks — Unity, CMock, and CException — all have `.c` file components. Ceedling also generates mocks and test runners with `.c` filename extensions regardless of any filename extension setting. Changing the source filename extension would cause Ceedling to miss its own core source files. This has been fixed.

### Bug fixes for `gcov` plugin

The most commonly reported bugs have been fixed:

* `nil` references
* Exit code issues with recent releases of `gcov`
* Empty coverage results and related build failures

### Bug fixes for `beep` plugin

A handful of small bugs in using shell `echo` with the ASCII bell character have been fixed.

### Which Ceedling handling includes new environment variable `WHICH_CEEDLING`

A previously semi-documented feature allowed you to point to a version of Ceedling on disk to run from within your project file, `:project` ↳ `:which_ceedling`.

This feature is primarily of use to Ceedling developers but can be useful in other specialized scenarios. See the documentation in _[CeedlingPacket](CeedlingPacket.md))_ for full deatils as this is an advanced feature.

The existing feature has been improved with logging and validation as well as proper documentation. An environment variable `WHICH_CEEDLING` is now also supported. If set, this variable supersedes any other settings. In the case of `ceedling new` and `ceedling upgrade`, it is the only way to change which Ceedling is in use as a project file either does not exist for the former or is not loaded for the latter.

## ⚠️ Changed

### Preprocessing improvements

Issues [#806](https://github.com/ThrowTheSwitch/Ceedling/issues/806) + [#796](https://github.com/ThrowTheSwitch/Ceedling/issues/796)

Preprocessing refers to expanding macros and other related code file text manipulations often needed in sophisticated projects before key test suite generation steps. Without (optional) preprocessing, generating test funners from test files and generating mocks from header files lead to all manner of build shenanigans.

The preprocessing needed by Ceedling for sophisticated projects has always been a difficult feature to implement. The most significant reason is simply that there is no readily available cross-platform C code preprocessing tool that provides Ceedling everything it needs to do its job. Even gcc’s `cpp` preprocessor tool comes up short. Over time Ceedling’s attempt at preprocessing grew more brittle and complicated as community contribturs attempted to fix it or cause it to work properly with other new features.

This release of Ceedling stripped the feature back to basics and largely rewrote it within the context of the new build pipeline. Complicated regular expressions and Ruby-generated temporary files have been eliminated. Instead, Ceedling now blends two reports from gcc' `cpp` tool and complements this with additional context. In addition, preprocessing now occurs at the right moments in the overall build pipeline.

While this new approach is not 100% foolproof, it is far more robust and far simpler than previous attempts. Other new Ceedling features should be able to address shortcomings in edge cases.

### Project file environment variable name change `CEEDLING_MAIN_PROJECT_FILE` ➡️ `CEEDLING_PROJECT_FILE`

Options and support for loading a project configuration have expanded significantly, mostly notably with the addition of Mixins.

The environment variable option for pointing Ceedling to a project file other than _project.yml_ in your working directory has been renamed `CEEDLING_MAIN_PROJECT_FILE` ➡️ `CEEDLING_PROJECT_FILE`.

Documentation on Mixins and the new options for loading a project configuration are thoroughly documented in _[CeedlingPacket](CeedlingPacket.md))_.

### Configuration defaults and configuration set up order

Ceedling’s previous handling of defaults and configuration processing order certainly worked, but it was not as proper as it could be. To oversimplify, default values were applied in an ordering that caused complications for advanced plugins and advanced users. This has been rectified. Default settings are now processed after all user configurations and plugins.

### Plugin system improvements

1. The plugin subsystem has incorporated logging to trace plugin activities at high verbosity levels.
1. Additional events have been added for test preprocessing steps (the popular and useful [`command_hooks` plugin](plugins/command_hooks/README.md) has been updated accordingly).
1. Built-in plugins have been updated for thread-safety as Ceedling is now able to execute builds with multiple threads.

### Logging improvements

Logging messages are more useful. A variety of logging messages have been added throughout Ceedling builds. Message labels (e.g. `ERROR:`) are now applied automatically). Exception handling is now centralized and significantly cleans up exception messages (backtraces are available with debug verbosity).

### Exit code options for test suite failures

Be default Ceedling terminates with an exit code of `1` when a build succeeds but unit tests fail.

A previously undocumented project configuration option `:graceful_fail` could force a Ceedling exit code of `0` upon test failures.

This configuration option has moved but is now [documented](CeedlingPacket.md). It is also available as a new command line argument (`--graceful-fail`).

```yaml
:test_build:
  :graceful_fail: TRUE
```

### Improved Segfault Handling in Test Suites

Segmentation faults are now reported as failures instead of an error with as much detail as possible. See the project configuration file documentation discussing the `:project` ↳ `:use_backtrace` option for more!

### Altered local documentation file directory structure

The application commands `ceedling new` and `ceedling upgrade` at the command line provide options for local copies of documentation when creating or upgrading a project. Previous versions of Ceedling used a flat file structure for the _docs/_ directory. Ceedling now uses subdirectories to organize plugin and tool documentation within the _docs/_ directory for clearer organization and preserving original filenames.

### JUnit, XML & JSON test report plugins consolidation

The three previously discrete plugins listed below have been consolidated into a single new plugin, `report_tests_log_factory`:

1. `junit_tests_report`
1. `json_tests_report`
1. `xml_tests_report`

`report_tests_log_factory` is able to generate all 3 reports of the plugins it replaces, a new HTML report, and custom report formats with a small amount of user-written Ruby code (i.e. not an entire Ceedling plugun). See its [documentation](../plugins/report_tests_log_factory) for more.

The report format of the previously independent `xml_tests_report` plugin has been renamed from _XML_ in all instances to _CppUnit_ as this is the specific test reporting format the former plugin and new `report_tests_log_factory` plugin outputs.

In some circumstances, JUnit report generation would yield an exception in its routines for reorganizing test results (Issues [#829](https://github.com/ThrowTheSwitch/Ceedling/issues/829) & [#833](https://github.com/ThrowTheSwitch/Ceedling/issues/833)). The true source of the nil test results entries has likely been fixed but protections have also been added in JUnit report generation as well.

### Improvements and changes for `gcov` plugin

1. Documentation has been significantly updated including a _Troubleshooting_ for common issues.
1. Compilation with coverage now only occurs for the source files under test and no longer for all C files (i.e. coverage for unity.c, mocks, and test files that is meaningless noise has been eliminated).
1. Coverage summaries printed to the console after `gcov:` test task runs now only concern the source files exercised instead of all source files. A final coverage tally has been restored.
1. Coverage summaries can now be disabled.
1. Coverage reports are now automatically generated after `gcov:` test tasks are executed. This behvaior can be disabled with a new configuration option. When enabled, a separate task is made available to trigger report generation.
1. To maintain consistency, repports generated by `gcovr` and `reportgenerator` are written to subdirectories named for the respective tools benath the `gcov/` artifacts path.

See the [gcov plugin’s documentation](plugins/gcov/README.md).

### Improvements for `compile_commands_json_db` plugin

1. The plugin creates a compilation database that distinguishes the same code file compiled multiple times with different configurations as part of the new test suite build structure. It has been updated to work with other Ceedling changes.
1. Documentation has been greatly revised.

### Improvements for `beep` plugin

1. Additional sound tools — `:tput`, `:beep`, and `:say` — have been added for more platform sound output options and fun.
1. Documentation has been greatly revised.
1. The plugin more properly uses looging and system shell calls.

## 👋 Removed

### `verbosity` and `log` command line tasks

These command line features were implemented using Rake. That is, they were Rake tasks, not command line switches, and they were subject to the peculiarities of Rake tasks. Specifically, order mattered — these tasks had to precede build tasks they were to affect — and `verbosity` required a non-standard parameter convention for numeric values.

These command line tasks no longer exist. They are now proper command line flags. These are most useful (and, in the case of logging, only availble) with Ceedling’s new `build` command line argument. The `build` command takes a list of build & plugin tasks to run. It is now complmented by `--verbosity`, `--log`, and `--logfile` flags. See the detailed help at `ceedling help build` for these.

The `build` keyword is optional. That is, omitting it is allowed and operates largely equivalent to the historical Ceedling command line.

The previous command line of `ceedling verbosity[4] test:all release` or `ceedling verbosity:obnoxious test:all release` can now be any of the following:

* `ceedling test:all release --verbosity=obnoxious`
* `ceedling test:all release -v 4`
* `ceedling --verbosity=obnoxious test:all release`
* `ceedling -v 4 test:all release`

Note that in the above list Ceedling is actually executing as though `ceedling build <args>` were entered at the command line. It is entirely acceptable to use the full form. The above list is provided as its form is the simplest to enter and consistent with previous versions of Ceedling.

### `options:` tasks

Options files were a simple but limited way to merge configuration with your base configuration from the command line. This feature has been superseded by Ceedling Mixins.

### Test suite smart rebuilds

All “smart” rebuild features built around Rake no longer exist. That is, incremental test suite builds for only changed files are no longer possible. Any test build is a full rebuild of its components (the speed increase due to parallel build tasks more than makes up for this).

These project configuration options related to smart builds are no longer recognized:
  - `:use_deep_dependencies`
  - `:generate_deep_dependencies`
  - `:auto_link_deep_dependencies`

In future revisions of Ceedling, smart rebuilds will be brought back (without relying on Rake) and without a list of possibly conflicting configuation options to control related features.

Note that release builds do retain a fair amount of smart rebuild capabilities. Release builds continue to rely on Rake (for now).

### Preprocessor support for Unity’s `TEST_CASE()` and `TEST_RANGE()`

Unity’s features `TEST_CASE()` and `TEST_RANGE()` continue to work but only when `:use_test_preprocessor` is disabled. The previous project configuration option `:use_preprocessor_directives` that preserved them when preprocessing is enabled is no longer recognized.

`TEST_CASE()` and `TEST_RANGE()` are macros that disappear when the preprocessor digests a test file. After preprocessing, they no longer exist in the test file that is compiled.

In future revisions of Ceedling, support for `TEST_CASE()` and `TEST_RANGE()` when preprocessing is enabled will be brought back (very likely without a dedicated configuration option — hopefully, we’ll get it to just work™️).

### Removed background task execution

Background task execution for tool configurations (`:background_exec`) has been deprecated. This option was one of Ceedling’s earliest features attempting to speed up builds within the constraints of relying on Rake. This feature has rarely, if ever, been used in practice, and other, better options exist to manage any scenario that might motivate a background task.

### Removed `colour_report` plugin

Colored build output and test results in your terminal is glorious. Long ago the `colour_report` plugin provided this. It was a simple plugin that hooked into Ceedling in a somewhat messy way. Its approach to coloring output was also fairly brittle. It long ago stopped coloring build output as intended. It has been removed.

Ceedling’s logging will eventually be updated to rely on a proper logging library. This will provide a number of important features along with greater speed and stability for the tool as a whole. This will also be the opportunity to add robust terminal text coloring support.

### Bullseye code coverage plugin temporarily disabled

The Gcov plugin has been updated and improved, but its proprietary counterpart, the [Bullseye](https://www.bullseye.com) plugin, is not presently functional. The needed fixes and updates require a software license that we do not (yet) have.

### Gcov plugin’s support for deprecated features removed

The configuration format for the `gcovr` utility changed when support for the `reportgenerator` utility was added. A format that accomodated a more uniform and common layout was adopted. However, support for the older, deprecated `gcovr`-only configuration was maintained. This support for the deprecated `gcovr` configuration format has been removed.

Please consult the [gcov plugin’s documentation](plugins/gcov/README.md) to update any old-style `gcovr` configurations.

### Gcov plugin’s `:abort_on_uncovered` option temporarily removed

Like Ceedling’s preprocessing features, the Gcov plugin had grown in features and complexity over time. The plugin had become difficult to maintain and some of its features had become user unfriendly at best and misleading at worst.

The Gcov plugin’s `:abort_on_uncovered` option plus the related `:uncovered_ignore_list` option were not preserved in this release. They will be brought back after some noodling on how to make these features user friendly again.

### Undocumented environment variable `CEEDLING_USER_PROJECT_FILE` support removed

A previously undocumented feature for merging a second configuration via environment variable `CEEDLING_USER_PROJECT_FILE` has been removed. This feature has been superseded by the new Mixins functionality.
