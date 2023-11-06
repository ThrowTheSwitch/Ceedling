# Ceedling Release Notes for 0.32 Release Candidate

**Version:** 0.32 pre-release incremental build

**Date:** November 6, 2023

<br/>

## 👀 Highlights

This Ceedling release is probably the most significant since the project was first posted to [SourceForge][sourceforge] in 2009.

Ceedling now runs in Ruby 3. Builds can now run much faster than previous versions because of parallelized tasks. For test suites, header file search paths, code defines, and tool run flags are now customizable per test executable.

### Avast, Breaking Changes, Ye Scallywags! 🏴‍☠️

**_Ahoy!_** There be **[breaking changes](#-Breaking-Changes)** ahead, mateys! Arrr…

### Big Deal Highlights 🏅

#### Ruby3

Ceedling now runs in Ruby3. This latest version of Ceedling is _not_ backwards compatible with earlier versions of Ruby.

#### Way faster execution with parallel build steps

Previously, Ceedling builds were depth-first and limited to a single line of execution. This limitation was an artifact of how Ceedling was architected and relying on general purpose Rake for the build pipeline. Rake does, in fact, support multi-threaded builds, but, Ceedling was unable to take advantage of this. As such, builds were limited to a single line of execution no matter how many CPU resources were available.

Ceedling 0.32 introduces a new build pipeline that batches build steps breadth-first. This means all test preprocessor steps, all compilation steps, all linking steps, etc. can benefit from concurrent and parallel execution. This speedup applies to both test suite and release builds.

#### Per-test-executable configurations

In previous versions of Ceedling each test executable was built with essentially the same global configuration. In the case of `#define`s and tool command line flags, individual files could be handled differently, but configuring Ceedling for doing so for all the files in any one test executable was tedious and error prone.

Now Ceedling builds each test executable as a mini project where header file search paths, compilation `#define`s, and tool flags can be specified per test executable. That is, each file that ultimately comprises a test executable is handled with the same configuration as the other files that make up that test executable.

Now you can have tests with quite different configurations and behaviors. Two tests need different mocks of the same header file? No problem. You want to test the same source file two different ways? We got you.

The following new features (discussed in later sections) contribute to this new ability:

- `TEST_INCLUDE_PATH(...)`. This build directive macro can be used within a test file to tell Ceedling which header search paths should be used during compilation. These paths are only used for compiling the files that comprise that test executable.
- `[:defines]` handling. `#define`s are now specified for the compilation of all modules comprising a test executable. Matching is only against test file names but now includes wildcard and regular expression options.
- `[:flags]` handling. Flags (e.g. `-std=c99`) are now specified for the build steps—preprocessing, compilation, and linking—of all modules comprising a test executable. Matching is only against test file names and now includes more sensible and robust wildcard and regular expression options.

### Medium Deal Highlights 🥈

#### `TEST_SOURCE_FILE(...)`

In previous versions of Ceedling, a new, undocumented build directive feature was introduced. Adding a call to the macro `TEST_FILE(...)` with a C file's name added that C file to the compilation and linking list for a test executable.

This approach was helpful when relying on a Ceedling convention was problematic. Specifically, `#include`ing a header file would cause any correspondingly named source file to be added to the build list for a test executable. This convention could cause problems if, for example, the header file defined symbols that complicated test compilation or behavior. Similarly, if a source file did not have a corresponding header file of the same name, sometimes the only option was to `#include` it directly; this was ugly and problematic in its own way.

The previously undocumented build directive macro `TEST_FILE(...)` has been renamed to `TEST_SOURCE_FILE(...)` and is now [documented](CeedlingPacket.md).

#### Preprocessing improvements

Ceedling has been around for a number of years and has had the benefit of many contributors over that time. Preprocessing is quite tricky to get right but is essential for big, complicated test suites. Over Ceedling's long life various patches and incremental improvements have evolved in such a way that preprocessing had become quite complicated and often did the wrong thing. Much of this has been fixed and improved in this release.

### Small Deal Highlights 🥉

- Effort has been invested across the project to improve error messages, exception handling, and exit code processing. Noisy backtraces have been relegated to the verbosity level of DEBUG as <insert higher power> intended.
- This release marks the beginning of the end for Rake as a backbone of Ceedling. Over many years it has become clear that Rake's design assumptions hamper building the sorts of features Ceedling's users want, Rake's command line structure creates a messy user experience for a full application built around it, and Rake's quirks cause maintenance challenges. Particularly for test suites, much of Ceedling's (invisible) dependence on Rake has been removed in this release. Much more remains to be done, including replicating some of the abilities Rake offers.
- This is the first ever release of Ceedling with proper release notes. Hello, there! Release notes will be a regular part of future Ceedling updates. If you haven't noticed already, this edition of the notes are detailed and quite lengthy. This is entirely due to how extensive the changes are in the 0.32 release. Future releases will have far shorter notes.

### Important Changes in Behavior to Be Aware Of 🚨

- **Test suite build order 🔢.** Ceedling no longer builds each test executable one at a time. From the tasks you provide at the command line, Ceedling now collects up and batches all preprocessing steps, all mock generation, all test runner generation, all compilation, etc. Previously you would see each of these done for a single test executable and then repeated for the next executable and so on. Now, each build step happens to completion for all specified tests before moving on to the next build step. 
- **Logging output order 🔢.** When multi-threaded builds are enabled, logging output may not be what you expect. Progress statements may be all batched together or interleaved in ways that are misleading. The steps are happening in the correct order. How you are informed of them may be somewhat out of order.
- **Files generated multiple times 🔀.** Now that each test is essentially a self-contained mini-project, some output may be generated multiple times. For instance, if the same mock is required by multiple tests, it will be generated multiple times. The same holds for compilation of source files into object files. A coming version of Ceedling will concentrate on optimizations to reuse any output that is truly identical across tests.
- **Test suite plugin runs 🏃🏻.** Because build steps are run to completion across all the tests you specify at the command line (e.g. all the mocks for your tests are generated at one time) you may need to adjust how you depend on build steps.

Together, these changes may cause you to think that Ceedling is running steps out of order or duplicating work. While bugs are always possible, more than likely, the output you see and the build ordering is expected.

<br/>

### 👋 Deprecated / Temporarily Removed Abilities

#### Test suite smart rebuilds

All “smart” rebuild features built around Rake no longer exist. That is, incremental test suite builds for only changed files are no longer possible. Any test build is a full rebuild of its components (the speed increase due to parallel build tasks more than makes up for this).

These project configuration options related to smart builds are no longer recognized:
  - `:use_deep_dependencies`
  - `:generate_deep_dependencies`
  - `:auto_link_deep_dependencies`

In future revisions of Ceedling, smart rebuilds will be brought back (without relying on Rake).

Note that release builds do retain a fair amount of smart rebuild capabilities. Release builds continue to rely on Rake (for now).

#### Preprocessor support for Unity's `TEST_CASE()` and `TEST_RANGE()`

The project configuration option `:use_preprocessor_directives` is no longer recognized.

**_Note:_** Unity's features `TEST_CASE()` and `TEST_RANGE()` continue to work but only when `:use_test_preprocessor` is disabled.

`TEST_CASE()` and `TEST_RANGE()` are do-nothing macros that disappear when the preprocessor digests a test file.

In future revisions of Ceedling, support for `TEST_CASE()` and `TEST_RANGE()` when preprocessing is enabled will be brought back.

#### Background task execution

Background task execution for tool configurations (`:background_exec`) has been deprecated. This option was one of Ceedling's earliest features attempting to speed up builds within the constraints of relying on Rake. This feature has rarely, if ever, been used in practice, and other, better options exist to manage any scenario that might motivate a background task.

<br/>


## 🌟 New Features

### Parallel execution of build steps

As was explained in the _[Highlights](#-Highlights)_, Ceedling can now run its internal tasks in parallel and take full advantage of your build system's resources. Even lacking various optimizations (see _[Known Issues](#-Known-Issues)_) builds are now often quite speedy.

Enabling this speedup requires either or both of two simple configuration settings. See Ceedling's [documentation](CeedlingPacket.md) for `[:project][:compile_threads]` and `[:project][:test_threads]`.

### `TEST_INCLUDE_PATH(...)`

Issue #743

### More better `[:flags]` handling

Issue #43

### More better `[:defines]` handling

…

<br/>

## 💪 Improvements and 🪲 Bug Fixes

### Preprocessing improvements

… Issues #806, #796

### Improvements and bug fixes for gcov plugin

1. Compilation with coverage now only occurs for the source files under test and no longer for all C files (.e.g. unity.c, mocks, and test files).
1. Coverage statistics printed to the console after `gcov:` test task runs now only concern the source files exercised instead of all source files.
1. Coverage reports are now automatically generated after `gcov:` test tasks are executed. This behvaior can be disabled with a new configuration option (a separate task is made available). See the [gcov plugin's documentation](plugins/gcov/README.md).

### Bug fixes for command line tasks `files:include` and `files:support`

Longstanding bugs produced duplicate and sometimes incorrect lists of header files. Similarly, support file lists were not properly expanded from globs. Both of these problems have been fixed.

### JUnit, XML & JSON test report plugins bug fix

When used with other plugins, the these test reporting plugins' generated report could end up in a location within `build/artifacts/` that was inconsistent and confusing. This has been fixed.

### Dashed filename handling bug fix

In certain combinations of Ceedling features, a dash in a C filename could cause Ceedling to exit with an exception (Issue #780). This has been fixed.

<br/>

## 💔 Breaking Changes

### Explicit `[:paths][:include]` entries in the project file

The `[:paths][:include]` entries in the project file must now be explicit and complete.

Eaerlier versions of Ceedling were rather accomodating when assembling the search paths for header files. The full list of directories was pulled from multiple `[:paths]` entries with de-duplication. If you had header files in your [:source] directories but did not explicitly list those directories in your `[:include]` paths, Ceedling would helpfully figure it out and use all the paths.

This behavior is no more. Why? For two interrelated reasons.

1. For large or complex projects, expansive header file search path lists can exceed command line maximum lengths on some platforms. An enforced, tailored set of search paths helps prevent this problem.
1. In order to support the desired behavior of `TEST_INCLUDE_PATH()` a concice set of “base” header file search paths is necessary. `[:paths][:include]` is that base list.

Using 0.32 Ceedling with older project files can lead to errors when generating mocks or compiler errors on finding header files. Add all paths to the `[:paths][:include]` project file entry to fix this problem.

### Format change for `[:defines]` in the project file

To better support per-test-executable configurations, the format of `[:defines]` has changed. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. A more logically named hierarchy differentiates `#define`s for test preprocessing, test compilation, and release compilation. The new format also allows a cleaner organization of `#define`s for configuration of tools like Unity.
1. Previously, `#define`s could be specified for a specific C file by name, but these `#define`s were only applied when compiling that specific file. Further, this matching was only against a file's full name. Now, pattern matching is also an option against test file names (only test file names) and the configured `#define`s are applied to each C file that comprises a test executable.

### Format change for `[:flags]` in the project file

To better support per-test-executable configurations, the format and function of `[flags]` has changed somewhat. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. All matching of file names is limited to test files. For any test file that matches, the specified flags are added to the named build step for all files that comprise that test executable. Previously, matching was against individual files, and flags were applied as such.
1. The format of the `[:flags]` configuration section is largely the same as in previous versions of Ceedling. The behavior of the matching rules is slightly different with more matching options.

### `TEST_FILE()` ➡️ `TEST_SOURCE_FILE()`

The previously undocumented `TEST_FILE()` build directive macro (#796) available within test files has been renamed and is now officially documented. See earlier section on this.

### Build output directory structure

Differentiating components of the same name that are a part of multiple test executables built with differing configurations has required further subdirectories in the build directory structure. Generated mocks, compiled object files, linked executables, and preprocessed output all end up one directory deeper than in previous versions of Ceedling. In each case, these files are found inside a subdirectory named for their containing test.

#### Tool `[:defines]`

In previous versions of Ceedling, one option for configuring compiled elements of vendor tools was to specify their `#define`s in that tool's project file configuration section. In conjunction with the general improvements to handling `#define`s, vendor tools' `#define`s now live in the top-level `[:defines]` area of the project configuration.

Note that to preserve some measure of backwards compatibility, Ceedling inserts a copy of a vendor tool's `#define` list into its top-level config.

Example of the old way:

```yaml
:unity:
  :defines:
    - UNITY_EXCLUDE_STDINT_H
    - UNITY_EXCLUDE_LIMITS_H
    - UNITY_EXCLUDE_SIZEOF
    - UNITY_INCLUDE_DOUBLE

:cmock:
  :defines:
    - CMOCK_MEM_STATIC
    - CMOCK_MEM_ALIGN=2
```

Example of the new way:

```yaml
:defines:
  :release:
    ... # Empty snippet
  :test:
    ... # Empty snippet
  :unity:
    - UNITY_EXCLUDE_STDINT_H
    - UNITY_EXCLUDE_LIMITS_H
    - UNITY_EXCLUDE_SIZEOF
    - UNITY_INCLUDE_DOUBLE
  :cmock:
    - CMOCK_MEM_STATIC
    - CMOCK_MEM_ALIGN=2
```

### Changes to global collections

Some global “collections” that were previously key elements of Ceedling have changed or gone away as the build pipeline is now able to process a configuration for each individual test executable in favor of for the entire suite.

- TODO: List collections

<br/>

## 🩼 Known Issues

1. The new internal pipeline that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization more than make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or header files of the same name in different directories for test runner and mock generation respectively continues to rely on educated guesses in Ceedling code.
1. Any path for a C file specified with `TEST_SOURCE_FILE(...)` is in relation to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, many of your `TEST_SOURCE_FILE(...)` may need to be updated. A more flexible and dynamic approach to path handling will come in a future update.
1. Fake Function Framework support in place of CMock mock generation is currently broken.
1. The gcov plugin has been updated and improved, but its counterpart, the [Bullseye plugin](plugins/bullseye/README.md), is not presently functional.

<br/>

## 📚 Background Knowledge

### Parallel execution of build steps

You may have heard that Ruby is actually only single-threaded or may know of its Global Interpreter Lock (GIL) that prevents parallel execution. To oversimplify a complicated subject, the Ruby implementations most commonly used to run Ceedling afford concurrency and true parallelism speedups but only in certain circumstances. It so happens that these circumstances are precisely the workload that Ceedling manages.

“Mainstream” Ruby implementations—not JRuby, for example—offer the following that Ceedling takes advantage of:

#### Native thread context switching on I/O operations

Since version 1.9, Ruby supports native threads and not only green threads. However, native threads are limited by the GIL to executing one at a time regardless of the number of cores in your processor. But, the GIL is “relaxed” for I/O operations.

When a native thread blocks for I/O, Ruby allows the OS scheduler to context switch to a thread ready to execute. This is the original benefit of threads when they were first developed back when CPUs contained a single core and multi-processor systems were rare and special. Ceedling does a fair amount of file and standard stream I/O in its pure Ruby code. Thus, when multiple threads are enabled in the proejct configuration file, execution can speed up for these operations.

#### Process spawning

Ruby's process spawning abilities have always mapped directly to OS capabilities. When a processor has multiple cores available, the OS tends to spread multiple child processes across those cores in true parallel execution.

Much of Ceedling's workload is executing a tool—such as a compiler—in a child process. With multiple threads enabled, each thread can spawn a child process for a build tool used by a build step. These child processes can be spread across multiple cores in true parallel execution.

<br/>

## 📣 Shoutouts

Thank yous and acknowledgments:

- …


[sourceforge]: https://sourceforge.net/projects/ceedling/ "Ceedling's public debut"