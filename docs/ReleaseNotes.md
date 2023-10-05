# Ceedling Release Notes for 0.32 Release Candidate

**Version:** 0.32 pre-release incremental build

**Date:** October 5, 2023

## 👀 Highlights

This Ceedling release is probably the most significant since the project was first posted to [SourceForge][sourceforge] in 2009.

Ceedling now runs in Ruby 3. Builds can now run much faster than previous versions because of parallelized tasks. Header file search paths, code defines, and tool run flags are now customizable per test executable.

### Big Deal Highlights 🏅

#### Ruby3

Ceedling now runs in Ruby3. This latest version of Ceedling is _not_ backwards compatible with earlier versions of Ruby.

#### Way faster suite execution with parallel build steps

Previously, Ceedling builds were depth-first. Each test executable built to completion and then ran with every other test ins uccession within the suite building to completion and running.

The previous build ordering was an artifact of relying on general purpose Rake for the build pipeline. This approach limited builds to a single line execution no matter how many CPU resources were available in your build system. Ceedling version 0.32 introduces a new build pipeline that batches build steps breadth-first. This means all preprocessor steps, all compilation steps, all linking steps, etc. can benefit from concurrent and parallel execution.

#### Per-test-executable configurations

In previous versions of Ceedling each test executable was built with essentially the same global configuration. In the case of `#define`s and tool command line flags, individual files could be handled differently, but configuring Ceedling for doing so for all the files in a test executable was tedious and error prone.

Now Ceedling builds each test executable as a mini project where header file search paths, compilation `#define`s, and tool flags can be specified per test executable. That is, each file that ultimately comprises a test executable is handled with the same configuration as the other files that make up that test executable.

The following new features (discussed in later sections) contribute to this new ability:

- `TEST_INCLUDE_PATH(...)`. This build directive macro can be used within a test file to tell Ceedling which header search paths should be used during compilation. These paths are only used for compiling the files that comprise that test executable.
- `[:defines]` definitions and matching in the project file. `#define`s are now specified for the compilation of all components of a test executable. Matching is only against test file names but now includes wildcard and regular expression options.
- `[:flags]` definitions and matching in the project file. Flags (e.g. `-std=c99`) are now specified for the build steps of all components of a test executable. Matching is only against test file names and now includes more sensible and robust wildcard and regular expression options.

### Medium Deal Highlights 🥈

#### `TEST_SOURCE_FILE(...)`

In previous versions of Ceedling, a new, undocumented build directive feature was introduced. Adding a call to the macro `TEST_FILE(...)` with a C file's name added that C file to the compilation and linking list for a test executable.

This approach was helpful when relying on a Ceedling convention was problematic. Specifically, `#include`ing a header file would cause any correspondingly named source file to be added to the build list for a test executable. This convention could cause problems if, for example, the header file defined symbols that complicated test compilation or behavior. Similarly, if a source file did not have a corresponding header file of the same name, sometimes the only option was to `#include` it directly; this was ugly and problematic in its own way.

The previously undocumented build directive macro `TEST_FILE(...)` has been renamed to `TEST_SOURCE_FILE(...)` and is now [documented](CeedlingPacket.md).

#### Preprocessing improvements

Ceedling has been around for a number of years and has had the benefit of many contributors over that time. Preprocessing is quite tricky to get right but is essential for big, complicated test suites. Over Ceedling's long life various patches and incremental improvements have evolved in such a way that preprocessing had become quite complicated and often did the wrong thing. Much of this has been fixed and improved in this release.

### Small Deal Highlights 🥉

- This release marks the beginning of the end for Rake as a backbone of Ceedling. Over many years it has become clear that Rake's design assumptions hamper building the sorts of features Ceedling's users want, Rake's command line structure creates a messy user experience, and Rake's quirks cause maintenance challenges. Much of Ceedling's (invisible) dependence on Rake has been removed in this release. Much more remains to be done, including replicating some of the abilities Rake offers.
- This is the first ever release of Ceedling with proper release notes. Release notes will be a regular part of future Ceedling updates. If you haven't noticed already, this edition of the notes are detailed and quite lengthy. This is entirely due to how extensive the changes are in this release. Future releases will have far shorter notes.

### 👋 Deprecated / Temporarily Removed Abilities

- All “smart” rebuild features built around Rake no longer exist. That is, incremental test suite builds for only changed files are no longer possible. In future revisions, this ability will be brought back without relying on Rake. In the meantime, all builds rebuild everything (the speed increase due to parallel build tasks more than makes up for this). The following project configuration options are no longer recognized:
  - `:use_deep_dependencies`
  - `:generate_deep_dependencies`
- Background task execution for tool configurations (`:background_exec`) has been deprecated. This option was one of Ceedling's earliest features attempting to speed up builds within the constraints of Rake-based builds. It has rarely if ever been used in practice, and other, better options exist to manage any sort of scenario that might motivate a background task.


#### Tool `[:defines]`

In previous versions of Ceedling, one option for configuring compiled elements of vendor tools was to specify their `#define`s in that tool's project file configuration section. In conjunction with the improvements to `#define`s handling generally, the tools' `#define`s no live in the top-level `[:defines]` area of the project configuration.

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


## 🌟 New Features

### 


## 💪 Improvements and 🪲 Bug Fixes

### Preprocessing improvements

…

### Improvements and bug fixes for gcov plugin

1. Compilation with coverage now only occurs for the source files under test and no longer for all C files (.e.g. unity.c, mocks, and test files).
1. Coverage statistics printed to the console after `gcov:` test task runs now only concern the source files exercised instead of all source files.
1. Coverage reports are now automatically generated after `gcov:` test tasks are executed. This behvaior can be disabled with a new configuration option (a separate task is made available). See the [gcov plugin's documentation](plugins/gcov/README.md).

### Bug fix for command line task `files:include`

A longstanding bug produced duplicate and sometimes incorrect lists of header files. This has been fixed.

### JUnit, XML & JSON test report plugins bug fix

When used with other plugins, the these test reporting plugins' generated report could end up in a location within `build/artifacts/` that was inconsistent and confusing. This has been fixed.

## 💔 Breaking Changes

### Explicit `[:paths][:include]` entries in the project file

The `[:paths][:include]` entries in the project file must now be explicit and complete.

Eaerlier versions of Ceedling were rather accomodating when assembling the search paths for header files. The full list of directories was pulled from multiple `[:paths]` entries with de-duplication. If you had header files in your [:source] directories but did not explicitly list those directories in your `[:include]` paths, Ceedling would helpfully figure it out and use all the paths.

This behavior is no more. Why? For two interrelated reasons.

1. For large or complex projects, expansive header file search path lists can exceed command line maximum lengths on some platforms. An enforced, tailored set of search paths helps prevent this problem.
1. In order to support the desired behavior of `TEST_INCLUDE_PATH()` a concice set of “base” header file search paths is necessary. `[:paths][:include]` is that base list.

Using 0.32 Ceedling with older project files can lead to compiler errors on finding header files. Add all paths to the `[:paths][:include]` project file entry to fix this problem.

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

The previously undocumented `TEST_FILE()` build directive macro available within test files has been renamed and is now officially documented. See earlier section on this.

### Build output directory structure

Differentiating components of the same name that are a part of multiple test executables built with differing configurations has required further subdirectories in the build directory structure. Generated mocks, compiled object files, linked executables, and preprocessed output all end up one directory deeper than in previous versions of Ceedling. In each case, these files are found inside a subdirectory named for their containing test.

### Changes to global collections

Some global “collections” that were previously key elements of Ceedling have changed or gone away as the build pipeline is now able to process a configuration for each individual test executable in favor of for the entire suite.
  - TODO: List collections

## 🩼 Known Issues

1. The new internal pipeline that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization more than make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or mockable header files of the same name in different directories continues to rely on educated guesses in Ceedling code.
1. Ceedling's new ability to support parallel build steps includes some rough areas:
  1. Threads do not always shut down immediately when build errors occur. This can introduce delays that look like mini-hangs. Builds do   eventually conclude. `<ctrl-c>` can help speed up the process.
  1. Certain “high stress” scenarios on Windows can cause data stream buffering errors. Many parallel build tasks with verbosity at an elevated level (>= 4) can lead to buffering failures when logging to the console.
  1. Error messages can be obscured by lengthy and duplicated backtraces across multiple threads.

## 📚 Background Knowledge

You may have heard that Ruby is actually only single-threaded or may know of its Global Interpreter Lock (GIL) that prevents parallel execution. To oversimplify a complicated subject, the Ruby implementations most commonly used to run Ceedling afford concurrency and true parallelism speedups but only in certain circumstances. It so happens that these circumstances are precisely the workload that Ceedling manages.

“Mainstream” Ruby implementations—not JRuby, for example—offer the following that Ceedling takes advantage of:

1. Since version 1.9, Ruby supports native threads and not only green threads. However, native threads are limited by the GIL to executing one at a time regardless of the number of cores in your processor. But, the GIL is “relaxed” for I/O operations. That is, when a thread blocks for I/O, Ruby allows the OS scheduler to context switch to a thread ready to execute. This is the original benefit of threads when they were first developed. Ceedling does a fair amount of file and standard stream I/O in its pure Ruby code. Thus, when threads are enabled in the proejct configuration file, execution can speed up for these operations.
1. Ruby's process spawning abilities have always mapped directly to OS capabilities. When a processor has multiple cores available, the OS tends to spread child processes across those cores in true parallel execution. Much of Ceedling's workload is executing a tool such as a compiler in a child process. When the project file allow multiple threads, build tasks can spawn multiple child processes across parallel cores.

## 📣 Shoutouts

Thank yous and acknowledgments:

- …
- …


[sourceforge]: https://sourceforge.net/projects/ceedling/ "Ceedling's public debut"