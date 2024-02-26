# Ceedling Release Notes for 0.32 Release Candidate

**Version:** 0.32 pre-release incremental build

**Date:** February 26, 2024

<br/>

## 👀 Highlights

This Ceedling release is probably the most significant since the project was first posted to [SourceForge][sourceforge] in 2009.

Ceedling now runs in Ruby 3. Builds can now run much faster than previous versions because of parallelized tasks. For test suites, header file search paths, code defines, and tool run flags are now customizable per test executable.

### Avast, Breaking Changes, Ye Scallywags! 🏴‍☠️

**_Ahoy!_** There be **[breaking changes](BreakingChanges.md)** ahead, mateys! Arrr…

### Big Deal Highlights 🏅

#### Ruby3

Ceedling now runs in Ruby3. This latest version of Ceedling is _not_ backwards compatible with earlier versions of Ruby.

#### Way faster execution with parallel build steps

Previously, Ceedling builds were depth-first and limited to a single line of execution. This limitation was an artifact of how Ceedling was architected and relying on general purpose Rake for the build pipeline. Rake does, in fact, support multi-threaded builds, but, Ceedling was unable to take advantage of this. As such, builds were limited to a single line of execution no matter how many CPU resources were available.

Ceedling 0.32 introduces a new build pipeline that batches build steps breadth-first. This means all test preprocessor steps, all compilation steps, all linking steps, etc. can benefit from concurrent and parallel execution. This speedup applies to both test suite and release builds.

#### Per-test-executable configurations

In previous versions of Ceedling each test executable was built with essentially the same global configuration. In the case of `#define`s and tool command line flags, individual files could be handled differently, but configuring Ceedling for doing so for all the files in any one test executable was tedious and error prone.

Now Ceedling builds each test executable as a mini project where header file search paths, compilation `#define` symbols, and tool flags can be specified per test executable. That is, each file that ultimately comprises a test executable is handled with the same configuration as the other files that make up that test executable.

Now you can have tests with quite different configurations and behaviors. Two tests need different mocks of the same header file? No problem. You want to test the same source file two different ways? We got you.

The following new features (discussed in later sections) contribute to this new ability:

- `TEST_INCLUDE_PATH(...)`. This build directive macro can be used within a test file to tell Ceedling which header search paths should be used during compilation. These paths are only used for compiling the files that comprise that test executable.
- `:defines` handling. `#define`s are now specified for the compilation of all modules comprising a test executable. Matching is only against test file names but now includes wildcard and regular expression options.
- `:flags` handling. Flags (e.g. `-std=c99`) are now specified for the build steps—preprocessing, compilation, and linking—of all modules comprising a test executable. Matching is only against test file names and now includes more sensible and robust wildcard and regular expression options.

### Medium Deal Highlights 🥈

#### `TEST_SOURCE_FILE(...)`

In previous versions of Ceedling, a new, undocumented build directive feature was introduced. Adding a call to the macro `TEST_FILE(...)` with a C file's name added that C file to the compilation and linking list for a test executable.

This approach was helpful when relying on a Ceedling convention was problematic. Specifically, `#include`ing a header file would cause any correspondingly named source file to be added to the build list for a test executable. This convention could cause problems if, for example, the header file defined symbols that complicated test compilation or behavior. Similarly, if a source file did not have a corresponding header file of the same name, sometimes the only option was to `#include` it directly; this was ugly and problematic in its own way.

The previously undocumented build directive macro `TEST_FILE(...)` has been renamed to `TEST_SOURCE_FILE(...)` and is now [documented](CeedlingPacket.md).

#### Preprocessing improvements

Ceedling has been around for a number of years and has had the benefit of many contributors over that time. Preprocessing (expanding macros in test files and header files to be mocked) is quite tricky to get right but is essential for big, complicated test suites. Over Ceedling's long life various patches and incremental improvements have evolved in such a way that preprocessing had become quite complicated and often did the wrong thing. Much of this has been fixed and improved in this release.

#### Documentation

The [Ceedling user guide](CeedlingPacket.md) has been significantly revised and expanded. We will expand it further in future releases and eventually break it up into multiple documents or migrate it to a full documentation management system.

Many of the plugins have received documentation updates as well.

There's more to be done, but Ceedling's documentation is more complete and accurate than it's ever been.

### Small Deal Highlights 🥉

- Effort has been invested across the project to improve error messages, exception handling, and exit code processing. Noisy backtraces have been relegated to the verbosity level of DEBUG as <insert higher power> intended.
- Logical ambiguity and functional bugs within `:paths` and `:files` configuration handling have been resolved along with updated documentation.
- A variety of small improvements and fixes have been made throughout the plugin system and to many plugins.
- The historically unwieldy `verbosity` command line task now comes in two flavors. The original recipe numeric parameterized version (e.g. `[4]`) exist as is. The new extra crispy recipe includes — funny enough — verbose task names `verbosity:silent`, `verbosity:errors`, `verbosity:complain`, `verbosity:normal`, `verbosity:obnoxious`, `verbosity:debug`. 
- This release marks the beginning of the end for Rake as a backbone of Ceedling. Over many years it has become clear that Rake's design assumptions hamper building the sorts of features Ceedling's users want, Rake's command line structure creates a messy user experience for a full application built around it, and Rake's quirks cause maintenance challenges. Particularly for test suites, much of Ceedling's (invisible) dependence on Rake has been removed in this release. Much more remains to be done, including replicating some of the abilities Rake offers.
- This is the first ever release of Ceedling with proper release notes. Hello, there! Release notes will be a regular part of future Ceedling updates. If you haven't noticed already, this edition of the notes are detailed and quite lengthy. This is entirely due to how extensive the changes are in the 0.32 release. Future releases will have far shorter notes.
- The `fake_function_framework` plugin has been renamed simply `fff`

### Important Changes in Behavior to Be Aware Of 🚨

- **Test suite build order 🔢.** Ceedling no longer builds each test executable one at a time. From the tasks you provide at the command line, Ceedling now collects up and batches all preprocessing steps, all mock generation, all test runner generation, all compilation, etc. Previously you would see each of these done for a single test executable and then repeated for the next executable and so on. Now, each build step happens to completion for all specified tests before moving on to the next build step. 
- **Logging output order 🔢.** When multi-threaded builds are enabled, logging output may not be what you expect. Progress statements may be all batched together or interleaved in ways that are misleading. The steps are happening in the correct order. How you are informed of them may be somewhat out of order.
- **Files generated multiple times 🔀.** Now that each test is essentially a self-contained mini-project, some output may be generated multiple times. For instance, if the same mock is required by multiple tests, it will be generated multiple times. The same holds for compilation of source files into object files. A coming version of Ceedling will concentrate on optimizations to reuse any output that is truly identical across tests.
- **Test suite plugin runs 🏃🏻.** Because build steps are run to completion across all the tests you specify at the command line (e.g. all the mocks for your tests are generated at one time) you may need to adjust how you depend on build steps.

Together, these changes may cause you to think that Ceedling is running steps out of order or duplicating work. While bugs are always possible, more than likely, the output you see and the build ordering is expected.

<br/>

### 👋 Deprecated or Temporarily Removed Abilities

#### Test suite smart rebuilds

All “smart” rebuild features built around Rake no longer exist. That is, incremental test suite builds for only changed files are no longer possible. Any test build is a full rebuild of its components (the speed increase due to parallel build tasks more than makes up for this).

These project configuration options related to smart builds are no longer recognized:
  - `:use_deep_dependencies`
  - `:generate_deep_dependencies`
  - `:auto_link_deep_dependencies`

In future revisions of Ceedling, smart rebuilds will be brought back (without relying on Rake) and without a list of possibly conflicting configuation options to control related features.

Note that release builds do retain a fair amount of smart rebuild capabilities. Release builds continue to rely on Rake (for now).

#### Preprocessor support for Unity's `TEST_CASE()` and `TEST_RANGE()`

The project configuration option `:use_preprocessor_directives` is no longer recognized.

**_Note:_** Unity's features `TEST_CASE()` and `TEST_RANGE()` continue to work but only when `:use_test_preprocessor` is disabled.

`TEST_CASE()` and `TEST_RANGE()` are do-nothing macros that disappear when the preprocessor digests a test file.

In future revisions of Ceedling, support for `TEST_CASE()` and `TEST_RANGE()` when preprocessing is enabled will be brought back.

#### Removed background task execution

Background task execution for tool configurations (`:background_exec`) has been deprecated. This option was one of Ceedling's earliest features attempting to speed up builds within the constraints of relying on Rake. This feature has rarely, if ever, been used in practice, and other, better options exist to manage any scenario that might motivate a background task.

#### Removed `colour_report` plugin

Colored build output and test results in your terminal is glorious. Long ago the `colour_report` plugin provided this. It was a simple plugin that hooked into Ceedling in a somewhat messy way. Its approach to coloring output was also fairly brittle. It long ago stopped coloring build output as intended. It has been removed.

Ceedling's logging will eventually be updated to rely on a proper logging library. This will provide a number of important features along with greater speed and stability for the tool as a whole. This will also be the opportunity to add robust terminal text coloring support.

#### Bullseye Plugin temporarily disabled

The gcov plugin has been updated and improved, but its proprietary counterpart, the [Bullseye](https://www.bullseye.com) plugin, is not presently functional. The needed fixes and updates require a software license that we do not (yet) have.

#### Gcov Plugin's support for deprecated features removed

The configuration format for the `gcovr` utility changed when support for the `reportgenerator` utility was added. A format that accomodated a more uniform and common layout was adopted. However, support for the older, deprecated `gcvor`-only configuration was maintained. This support for the deprecated `gcvor` configuration format has been removed.

Please consult the [gcov plugin's documentation](plugins/gcov/README.md) to update any old-style `gcovr` configurations.

<br/>

## 🌟 New Features

### Parallel execution of build steps

As was explained in the _[Highlights](#-Highlights)_, Ceedling can now run its internal tasks in parallel and take full advantage of your build system's resources. Even lacking various optimizations (see _[Known Issues](#-Known-Issues)_) builds are now often quite speedy.

Enabling this speedup requires either or both of two simple configuration settings. See Ceedling's [documentation](CeedlingPacket.md) for `:project` ↳ `:compile_threads` and `:project` ↳ `:test_threads`.

### `TEST_INCLUDE_PATH(...)` & `TEST_SOURCE_FILE(...)`

Issue [#743](https://github.com/ThrowTheSwitch/Ceedling/issues/743)

Using what we are calling build directive macros, you can now provide Ceedling certain configuration details from inside a test file.

See the [documentation](CeedlingPacket.md) discussion on include paths, Ceedling conventions, and these macros to understand all the details.

_Note:_ Ceedling is not yet capable of preserving build directive macros through preprocessing of test files. If, for example, you wrap these macros in
        conditional compilation preprocessing statements, they will not work as you expect.

#### `TEST_INCLUDE_PATH(...)` 

In short, `TEST_INCLUDE_PATH()` allows you to add a header file search path to the build of the test executable in which it is found. This can mean much shorter compilation command lines and good flexibility for complicated projects.

#### `TEST_SOURCE_FILE(...)`

In short, `TEST_SOURCE_FILE()` allows you to be explicit as to which source C files should be compiled and linked into a test executable. Sometimes Ceedling's convention for matching source files with test files by way of `#include`d header files does not meet the need. This solves the problems of those scenarios.

### More better `:flags` handling

Issue [#43](https://github.com/ThrowTheSwitch/Ceedling/issues/43)

Each test executable is now built as a mini project. Using improved `:flags` handling and an updated section format within Ceedling's project file, you have much better options for specifying flags presented to the various tools within your build, particulary within test builds.

### More better `:defines` handling

Each test executable is now built as a mini project. Using improved `:defines` handling and an updated section format within Ceedling's project file, you have much better options for specifying symbols used in your builds' compilation steps, particulary within test builds.

One powerful new feature is the ability to test the same source file built differently for different tests. Imagine a source file has three different conditional compilation sections. You can now write unit tests for each of those sections without complicated gymnastics to cause your test suite to build and run properly.

<br/>

## 💪 Improvements and 🪲 Bug Fixes

### Preprocessing improvements

Issues [#806](https://github.com/ThrowTheSwitch/Ceedling/issues/806) + [#796](https://github.com/ThrowTheSwitch/Ceedling/issues/796)

Preprocessing refers to expanding macros and other related code file text manipulations often needed in sophisticated projects before key test suite generation steps. Without (optional) preprocessing, generating test funners from test files and generating mocks from header files lead to all manner of build shenanigans.

The preprocessing needed by Ceedling for sophisticated projects has always been a difficult feature to implement. The most significant reason is simply that there is no readily available cross-platform C code preprocessing tool that provides Ceedling everything it needs to do its job. Even gcc's `cpp` preprocessor tool comes up short. Over time Ceedling's attempt at preprocessing grew more brittle and complicated as community contribturs attempted to fix it or cause it to work properly with other new features.

This release of Ceedling stripped the feature back to basics and largely rewrote it within the context of the new build pipeline. Complicated regular expressions and Ruby-generated temporary files have been eliminated. Instead, Ceedling now blends two reports from gcc' `cpp` tool and complements this with additional context. In addition, preprocessing now occurs at the right moments in the overall build pipeline.

While this new approach is not 100% foolproof, it is far more robust and far simpler than previous attempts. Other new Ceedling features should be able to address shortcomings in edge cases.

### `:paths` and `:files` handling bug fixes and clarification

Most project configurations are relatively simple, and Ceedling's features for collecting paths worked fine enough. However, bugs and ambiguities lurked. Further, insufficient validation left users resorting to old fashioned trial-and-error troubleshooting.

Much glorious filepath and pathfile handling now abounds:

* The purpose and use of `:paths` and `:files` has been clarified in both code and documentation. `:paths` are directory-oriented while `:files` are filepath-oriented.
* [Documentation](CeedlingPacket.md) is now accurate and complete.
* Path handling edge cases have been properly resolved (`./foo/bar` is the same as `foo/bar` but was not always processed as such).
* Matching globs were advertised in the documentation (erroneously, incidentally) but lacked full programmatic support.
* Ceedling now tells you if your matching patterns don't work. Unfortunately, all Ceedling can determine is if a particular pattern yielded 0 results.

### Plugin system improvements

1. The plugin subsystem has incorporated logging to trace plugin activities at high verbosity levels.
1. Additional events have been added for test preprocessing steps (the popular and useful [`command_hooks` plugin](plugins/command_hooks/README.md) has been updated accordingly).
1. Built-in plugins have been updated for thread-safety as Ceedling is now able to execute builds with multiple threads.

### Improvements, changes, and bug fixes for `gcov` plugin

1. Documentation has been significantly updated including a _Troubleshooting_ for common issues.
1. Compilation with coverage now only occurs for the source files under test and no longer for all C files (i.e. coverage for unity.c, mocks, and test files that is meaningless noise has been eliminated).
1. Coverage summaries printed to the console after `gcov:` test task runs now only concern the source files exercised instead of all source files. A final coverage tally has been restored.
1. Coverage summaries can now be disabled.
1. Coverage reports are now automatically generated after `gcov:` test tasks are executed. This behvaior can be disabled with a new configuration option. When enabled, a separate task is made available to trigger report generation.
1. To maintain consistency, repports generated by `gcovr` and `reportgenerator` are written to subdirectories named for the respective tools benath the `gcov/` artifacts path.

See the [gcov plugin's documentation](plugins/gcov/README.md).

### Bug fixes for command line tasks `files:header` and `files:support`

Longstanding bugs produced duplicate and sometimes incorrect lists of header files. Similarly, support file lists were not properly expanded from globs. Both of these problems have been fixed. The `files:header` command line task has replaced the `files:include` task.

### Improvements and bug fixes for `compile_commands_json_db` plugin

1. The plugin creates a compilation database that distinguishes the same code file compiled multiple times with different configurations as part of the new test suite build structure. It has been updated to work with other Ceedling changes and small bugs have been fixed.
1. Documentation has been greatly revised.

### Improvements and bug fixes for `beep` plugin

1. Additional sound tools — `:tput`, `:beep`, and `:say` — have been added for more platform sound output options and fun.
1. Documentation has been greatly revised.
1. The plugin more properly uses looging and system shell calls.
1. Small bugs in using `echo` and the ASCII bell character have been fixed.

### JUnit, XML & JSON test report plugins: Bug fixes and consolidation

When used with other plugins, these test reporting plugins' generated report could end up in a location within `build/artifacts/` that was inconsistent and confusing. This has been fixed.

The three previously discrete plugins listed below have been consolidated into a single new plugin, `report_tests_log_factory`:

1. `junit_tests_report`
1. `json_tests_report`
1. `xml_tests_report`

`report_tests_log_factory` is able to generate all 3 reports of the plugins it replaces as well as generate custom report formats with a small amount of user-written Ruby code (i.e. not an entire Ceedling plugun). See its [documentation](../plugins/report_tests_log_factory) for more.

The report format of the previously independent `xml_tests_report` plugin has been renamed from _XML_ in all instances to _CppUnit_ as this is the specific test reporting format the former plugin and new `report_tests_log_factory` plugin outputs.

In some circumstances, JUnit report generation would yield an exception in its routines for reorganizing test results (Issues [#829](https://github.com/ThrowTheSwitch/Ceedling/issues/829) & [#833](https://github.com/ThrowTheSwitch/Ceedling/issues/833)). The true source of the nil test results entries has likely been fixed but protections have also been added in JUnit report generation as well.

### Dashed filename handling bug fix

Issue [#780](https://github.com/ThrowTheSwitch/Ceedling/issues/780)

In certain combinations of Ceedling features, a dash in a C filename could cause Ceedling to exit with an exception. This has been fixed.

### Source filename extension handling bug fix

Issue [#110](https://github.com/ThrowTheSwitch/Ceedling/issues/110)

Ceedling has long had the ability to configure a source filename extension other than `.c` (`:extension` ↳ `:source`). However, in most circumstances this ability would lead to broken builds. Regardless of user-provided source files and filename extenion settings, Ceedling's supporting frameworks — Unity, CMock, and CException — all have `.c` file components. Ceedling also generates mocks and test runners with `.c` filename extensions regardless of any filename extension setting. Changing the source filename extension would cause Ceedling to miss its own core source files. This has been fixed. 

<br/>

## 🩼 Known Issues

1. The new internal pipeline that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization more than make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or header files of the same name in different directories for test runner and mock generation respectively continues to rely on educated guesses in Ceedling code.
1. Any path for a C file specified with `TEST_SOURCE_FILE(...)` is in relation to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, many of your `TEST_SOURCE_FILE(...)` calls may need to be updated. A more flexible and dynamic approach to path handling will come in a future update.

<br/>

## 📚 Background Knowledge

### Parallel execution of build steps

You may have heard that Ruby is actually only single-threaded or may know of its Global Interpreter Lock (GIL) that prevents parallel execution. To oversimplify a complicated subject, the Ruby implementations most commonly used to run Ceedling afford concurrency and true parallelism speedups but only in certain circumstances. It so happens that these circumstances are precisely the workload that Ceedling manages.

“Mainstream” Ruby implementations — not JRuby, for example — offer the following that Ceedling takes advantage of:

#### Native thread context switching on I/O operations

Since version 1.9, Ruby supports native threads and not only green threads. However, native threads are limited by the GIL to executing one at a time regardless of the number of cores in your processor. But, the GIL is “relaxed” for I/O operations.

When a native thread blocks for I/O, Ruby allows the OS scheduler to context switch to a thread ready to execute. This is the original benefit of threads when they were first developed back when CPUs contained a single core and multi-processor systems were rare and special. Ceedling does a fair amount of file and standard stream I/O in its pure Ruby code. Thus, when multiple threads are enabled in the proejct configuration file, execution can speed up for these operations.

#### Process spawning

Ruby's process spawning abilities have always mapped directly to OS capabilities. When a processor has multiple cores available, the OS tends to spread multiple child processes across those cores in true parallel execution.

Much of Ceedling's workload is executing a tool — such as a compiler — in a child process. With multiple threads enabled, each thread can spawn a child process for a build tool used by a build step. These child processes can be spread across multiple cores in true parallel execution.

<br/>

## 📣 Shoutouts

Thank yous and acknowledgments:

- …


[sourceforge]: https://sourceforge.net/projects/ceedling/ "Ceedling's public debut"