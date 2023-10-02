# Ceedling Release Notes for 0.32 Release Candidate

**Version:** 0.32 pre-release incremental build

**Date:** October 2, 2023

## 👀 Highlights

This Ceedling release is probably the most significant since the project was first posted to [SourceForge][1] in 2009.

Ceedling now runs in Ruby 3. Builds can now run much faster than previous versions because of parallelized tasks. Header file search paths, code defines, and tool run flags are now customizable per test executable.

### Big Deal

**Ruby3.** Ceedling now runs in Ruby3. This latest version is not backwards compatible with earlier versions of Ruby.

**Faster builds.** Previously, Ceedling builds were depth first through a chain of dependencies from code files through to individual test executables. Each test executable built to completion and then ran until all executables in the suite had run. This was an artifact of relying on Rake for the build pipeline and limited builds no matter how many resources were available in your build system. Ceedling version 0.32 introduces a new build pipeline that batches build steps breadth first. This means all preprocessor steps, all compilation steps, etc. can benefit from concurrent and parallel execution.

**Per test executable configurations.** In previous versions of Ceedling each test executable was built with the same global configuration. In the case of #defines and tool flags, individual files could be handled differently but configuring Ceedling for doing so for all the files in a test executable was tedious and error prone. Now Ceedling builds each test executable as a mini project where header file search paths, compilation #defines, and tool flags can be specified per test executable. That is, each file that ultimately comprises a test executable is handled with the same configuration as the other files that make up that test executable.

- `TEST_INCLUDE_PATH()`
- `[:defines]` matching
- `[:flags]` matching

### Medium Deal

- `TEST_SOURCE_FILE()`

### Small Deal

…

---

## 🌟 New Features

…

---

## 💪 Improvements and 🪲 Bug Fixes

…

---

## 💔 Breaking Changes

…

---

## 🩼 Known Issues

1. The new internal pipeline that allows builds to be parallelized and configured per test executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled itentically multiple times. The speed gains due to parallelization more than make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or mockable header files of the same name in different directories continues to rely on some educated guesses in code.
1. Ceedling's new ability to support parallel build steps includes some rough areas
  1. Threads do not always shut down immediately when build errors occur. This can introduce delays that look like mini-hangs. Builds do   eventually conclude. `<ctrl-c>` can help speed up the process.
  1. Certain “high stress” scenarios on Windows can cause data stream buffering errors. Many parallel build tasks with verbosity at an elevated   level (>= 4) can lead to buffering failures when logging to the console.
  1. Error messages can be obscured by lengthy and duplicated backtraces.

## 📚 Background Knowledge

You may have heard that Ruby is actually only single-threaded or may know of its Global Interpreter Lock (GIL) that prevents parallel execution. To oversimplify a complicated subject, the Ruby implementations most commonly used to run Ceedling afford concurrency speedups and true parallelism but only in certain circumstances. It so happens that these circumstances are precisely the workload that Ceedling manages.

Mainstream Ruby implementations (not JRuby, for example) offer the following that Ceedling takes advantage of:

1. Since version 1.9, Ruby supports native threads. However, native threads are limited by the GIL to executing one at a time regardless of the number of cores in your processor. But, the GIL is “relaxed” for I/O operations. That is, when a thread blocks for I/O, Ruby allows the OS scheduler to context switch to a thread ready to execute. This is the original benefit of threads when they were first developed. Ceedling does a fair amount of file and standard stream I/O in its pure Ruby code. Thus, when threads are enabled in the proejct configuration file, execution can speed up for these operations.
1. Ruby's process spawning abilities have always mapped directly to OS capabilities. When a processor has multiple cores available, the OS tends to spread child processes across them in true parallel execution. Much of Ceedling's workload is executing a tool such as a compiler in a child process. When the project file allow multiple threads, build tasks can spawn multiple child processes across parallel cores.

## 📣 Shoutouts

Thank yous and acknowledgments:

- …
- …


[1]: https://sourceforge.net/projects/ceedling/ "Ceedling's public debut"