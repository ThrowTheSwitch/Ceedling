# 🌱 Ceedling Release Notes

These release notes are complemented by two other documents:

1. 🪵 **[Changelog](Changelog.md)** for a structured list of additions, fixes, changes, and removals.
1. 💔 **[Breaking Changes](BreakingChanges.md)** for a list of impacts to existing Ceedling projects.

---

# 1.0.0 pre-release — April 2, 2024

## 🏴‍☠️ Avast, Breaking Changes, Ye Scallywags!

**_Ahoy!_** There be plenty o’ **[breaking changes](BreakingChanges.md)** ahead, mateys! Arrr…

## 👀 Highlights

This Ceedling release is probably the most significant since the project was first posted to [SourceForge][sourceforge] in 2009. See the [Changelog](Changelog.md) for all the details.

Ceedling now runs in Ruby 3. Builds can now run much faster than previous versions because of parallelized tasks. For test suites, header file search paths, code defines, and tool run flags are now customizable per test executable.

### Big Deal Highlights 🏅

#### Ruby3

Ceedling now runs in Ruby3. This latest version of Ceedling is _not_ backwards compatible with earlier versions of Ruby.

#### Way faster execution with parallel build steps

Previously, Ceedling builds were depth-first and limited to a single line of execution. This limitation was an artifact of how Ceedling was architected and relying on general purpose Rake for the build pipeline. Rake does, in fact, support multi-threaded builds, but, Ceedling was unable to take advantage of this. As such, builds were limited to a single line of execution no matter how many CPU resources were available.

Ceedling 1.0.0 introduces a new build pipeline that batches build steps breadth-first. This means all test preprocessor steps, all compilation steps, all linking steps, etc. can benefit from concurrent and parallel execution. This speedup applies to both test suite and release builds.

#### Per-test-executable configurations

In previous versions of Ceedling each test executable was built with essentially the same global configuration. In the case of `#define`s and tool command line flags, individual files could be handled differently, but configuring Ceedling for doing so for all the files in any one test executable was tedious and error prone.

Now Ceedling builds each test executable as a mini project where header file search paths, compilation `#define` symbols, and tool flags can be specified per test executable. That is, each file that ultimately comprises a test executable is handled with the same configuration as the other files that make up that test executable.

Now you can have tests with quite different configurations and behaviors. Two tests need different mocks of the same header file? No problem. You want to test the same source file two different ways? We got you.

The following new features (discussed in later sections) contribute to this new ability:

- `TEST_INCLUDE_PATH(...)`. This build directive macro can be used within a test file to tell Ceedling which header search paths should be used during compilation. These paths are only used for compiling the files that comprise that test executable.
- `:defines` handling. `#define`s are now specified for the compilation of all modules comprising a test executable. Matching is only against test file names but now includes wildcard and regular expression options.
- `:flags` handling. Flags (e.g. `-std=c99`) are now specified for the build steps—preprocessing, compilation, and linking—of all modules comprising a test executable. Matching is only against test file names and now includes more sensible and robust wildcard and regular expression options.

#### Mixins for configuration variations

Ever wanted to smoosh in some extra configuration selectively? Let’s say you have different build scenarios and you'd like to run different variations of your project for them. Maybe you have core configuration that is common to all those scenarios. Previous versions of Ceedling included a handful of features that partially met these sorts of needs.

All such features have been superseded by _Mixins_. Mixins are simply additional YAML that gets merged into you base project configuration. However, Mixins provide several key improvements over previous features:

1. Mixins can be as little or as much configuration as you want. You could push all your configuration into mixins with a base project file including nothing but a `:mixins` section.
1. Mixins can be specified in your project configuration, via environment variables, and from the command line. A clear order of precedence controls the order of merging. Any conflicts or duplicates are automatically resolved.
1. Logging makes clear what proejct file and mixins are loaded and merged at startup.
1. Like built-in plugins, Ceedling will soon come with built-in mixins available for common build scenarios.

#### A proper command line

Until this release, Ceedling depended on Rake for most of its command line handling. Rake’s task conventions provide poor command line handling abilities. The core problems with Rake command line handling include:

1. Only brief, limited help statements.
1. No optional flags to modify a task — verbosity, logging, etc. were their own tasks.
1. Complex/limited parameterization (e.g. `verbosity[3]` instead of `--verbosity normal`).
1. Tasks are order-dependent. So, for example, `test:all verbosity[5]` changes verbosity after the tests are run.

Ceedling now offers a full command line interface with rich help, useful order-independent option flags, and more.

The existing `new`, `upgrade`, and `example` commands remain but have been improved. You may now even specify the project file to load, log file to write to, and exit code handling behavior from the command line.

Try `ceedling help` and then `ceedling help <command>` to get started.

### Medium Deal Highlights 🥈

#### `TEST_SOURCE_FILE(...)`

In previous versions of Ceedling, a new, undocumented build directive feature was introduced. Adding a call to the macro `TEST_FILE(...)` with a C file’s name added that C file to the compilation and linking list for a test executable.

This approach was helpful when relying on a Ceedling convention was problematic. Specifically, `#include`ing a header file would cause any correspondingly named source file to be added to the build list for a test executable. This convention could cause problems if, for example, the header file defined symbols that complicated test compilation or behavior. Similarly, if a source file did not have a corresponding header file of the same name, sometimes the only option was to `#include` it directly; this was ugly and problematic in its own way.

The previously undocumented build directive macro `TEST_FILE(...)` has been renamed to `TEST_SOURCE_FILE(...)` and is now [documented](CeedlingPacket.md).

#### Preprocessing improvements

Ceedling has been around for a number of years and has had the benefit of many contributors over that time. Preprocessing (expanding macros in test files and header files to be mocked) is quite tricky to get right but is essential for big, complicated test suites. Over Ceedling’s long life various patches and incremental improvements have evolved in such a way that preprocessing had become quite complicated and often did the wrong thing. Much of this has been fixed and improved in this release.

#### Documentation

The Ceedling user guide, _[CeedlingPacket](CeedlingPacket.md)_, has been significantly revised and expanded. We will expand it further in future releases and eventually break it up into multiple documents or migrate it to a full documentation management system.

Many of the plugins have received documentation updates as well.

There’s more to be done, but Ceedling’s documentation is more complete and accurate than it’s ever been.

### Small Deal Highlights 🥉

- Effort has been invested across the project to improve error messages, exception handling, and exit code processing. Noisy backtraces have been relegated to the verbosity level of DEBUG as <insert higher power> intended.
- Logical ambiguity and functional bugs within `:paths` and `:files` configuration handling have been resolved along with updated documentation.
- A variety of small improvements and fixes have been made throughout the plugin system and to many plugins.
- The historically unwieldy `verbosity` command line task now comes in two flavors. The original recipe numeric parameterized version (e.g. `[4]`) exist as is. The new extra crispy recipe includes — funny enough — verbose task names `verbosity:silent`, `verbosity:errors`, `verbosity:complain`, `verbosity:normal`, `verbosity:obnoxious`, `verbosity:debug`. 
- This release marks the beginning of the end for Rake as a backbone of Ceedling. Over many years it has become clear that Rake’s design assumptions hamper building the sorts of features Ceedling’s users want, Rake’s command line structure creates a messy user experience for a full application built around it, and Rake’s quirks cause maintenance challenges. Particularly for test suites, much of Ceedling’s (invisible) dependence on Rake has been removed in this release. Much more remains to be done, including replicating some of the abilities Rake offers.
- This is the first ever release of Ceedling with proper release notes. Hello, there! Release notes will be a regular part of future Ceedling updates. If you haven't noticed already, this edition of the notes are detailed and quite lengthy. This is entirely due to how extensive the changes are in the 1.0.0 release. Future releases will have far shorter notes.
- The `fake_function_framework` plugin has been renamed simply `fff`

### Important Changes in Behavior to Be Aware Of 🚨

- **Test suite build order 🔢.** Ceedling no longer builds each test executable one at a time. From the tasks you provide at the command line, Ceedling now collects up and batches all preprocessing steps, all mock generation, all test runner generation, all compilation, etc. Previously you would see each of these done for a single test executable and then repeated for the next executable and so on. Now, each build step happens to completion for all specified tests before moving on to the next build step. 
- **Logging output order 🔢.** When multi-threaded builds are enabled, logging output may not be what you expect. Progress statements may be all batched together or interleaved in ways that are misleading. The steps are happening in the correct order. How you are informed of them may be somewhat out of order.
- **Files generated multiple times 🔀.** Now that each test is essentially a self-contained mini-project, some output may be generated multiple times. For instance, if the same mock is required by multiple tests, it will be generated multiple times. The same holds for compilation of source files into object files. A coming version of Ceedling will concentrate on optimizations to reuse any output that is truly identical across tests.
- **Test suite plugin runs 🏃🏻.** Because build steps are run to completion across all the tests you specify at the command line (e.g. all the mocks for your tests are generated at one time) you may need to adjust how you depend on build steps.

Together, these changes may cause you to think that Ceedling is running steps out of order or duplicating work. While bugs are always possible, more than likely, the output you see and the build ordering is expected.

## 🩼 Known Issues

1. The new internal pipeline that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization more than make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or header files of the same name in different directories for test runner and mock generation respectively continues to rely on educated guesses in Ceedling code.
1. Any path for a C file specified with `TEST_SOURCE_FILE(...)` is in relation to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, many of your `TEST_SOURCE_FILE(...)` calls may need to be updated. A more flexible and dynamic approach to path handling will come in a future update.

## 📚 Background Knowledge

### Parallel execution of build steps

You may have heard that Ruby is actually only single-threaded or may know of its Global Interpreter Lock (GIL) that prevents parallel execution. To oversimplify a complicated subject, the Ruby implementations most commonly used to run Ceedling afford concurrency and true parallelism speedups but only in certain circumstances. It so happens that these circumstances are precisely the workload that Ceedling manages.

“Mainstream” Ruby implementations — not JRuby, for example — offer the following that Ceedling takes advantage of:

#### Native thread context switching on I/O operations

Since version 1.9, Ruby supports native threads and not only green threads. However, native threads are limited by the GIL to executing one at a time regardless of the number of cores in your processor. But, the GIL is “relaxed” for I/O operations.

When a native thread blocks for I/O, Ruby allows the OS scheduler to context switch to a thread ready to execute. This is the original benefit of threads when they were first developed back when CPUs contained a single core and multi-processor systems were rare and special. Ceedling does a fair amount of file and standard stream I/O in its pure Ruby code. Thus, when multiple threads are enabled in the proejct configuration file, execution can speed up for these operations.

#### Process spawning

Ruby’s process spawning abilities have always mapped directly to OS capabilities. When a processor has multiple cores available, the OS tends to spread multiple child processes across those cores in true parallel execution.

Much of Ceedling’s workload is executing a tool — such as a compiler — in a child process. With multiple threads enabled, each thread can spawn a child process for a build tool used by a build step. These child processes can be spread across multiple cores in true parallel execution.

## 📣 Shoutouts

Thank yous and acknowledgments:

- …


[sourceforge]: https://sourceforge.net/projects/ceedling/ "Ceedling’s public debut"