
# 💔 Breaking Changes for 0.32 Release Candidate

**Version:** 0.32 pre-release incremental build

**Date:** December 26, 2023

## Explicit `:paths` ↳ `:include` entries in the project file

The `:paths` ↳ `:include` entries in the project file must now be explicit and complete.

Eaerlier versions of Ceedling were rather accomodating when assembling the search paths for header files. The full list of directories was pulled from multiple `:paths` entries with de-duplication. If you had header files in your `:source` directories but did not explicitly list those directories in your `:include` paths, Ceedling would helpfully figure it out and use all the paths.

This behavior is no more. Why? For two interrelated reasons.

1. For large or complex projects, expansive header file search path lists can exceed command line maximum lengths on some platforms. An enforced, tailored set of search paths helps prevent this problem.
1. In order to support the desired behavior of `TEST_INCLUDE_PATH()` a concice set of “base” header file search paths is necessary. `:paths` ↳ `:include` is that base list.

Using 0.32 Ceedling with older project files can lead to errors when generating mocks or compiler errors on finding header files. Add all paths to the `:paths` ↳ `:include` project file entry to fix this problem.

## Format change for `:defines` in the project file

To better support per-test-executable configurations, the format of `:defines` has changed. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. A more logically named hierarchy differentiates `#define`s for test preprocessing, test compilation, and release compilation.
1. Previously, compilation symbols could be specified for a specific C file by name, but these symbols were only defined when compiling that specific file. Further, this matching was only against a file's full name. Now, pattern matching is also an option against test file names (_only_ test file names) and the configured symbols are applied in compilation of each C file that comprises a test executable.

## Format change for `:flags` in the project file

To better support per-test-executable configurations, the format and function of `:flags` has changed somewhat. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. All matching of file names is limited to test files. For any test file that matches, the specified flags are added to the named build step for all files that comprise that test executable. Previously, matching was against individual files, and flags were applied as such.
1. The format of the `:flags` configuration section is largely the same as in previous versions of Ceedling. The behavior of the matching rules is slightly different with more matching options.

## `TEST_FILE()` ➡️ `TEST_SOURCE_FILE()`

The previously undocumented `TEST_FILE()` build directive macro (#796) available within test files has been renamed and is now officially documented. See earlier section on this.

## Build output directory structure changes

### Test builds

Each test is now treated as its own mini-project. Differentiating components of the same name that are a part of multiple test executables required further subdirectories in the build directory structure. Generated mocks, compiled object files, linked executables, and preprocessed output all end up one directory deeper than in previous versions of Ceedling. In each case, these files are found inside a subdirectory named for their containing test.

### Release builds

Release build object files were previously segregated by their source. The release build output directory had subdirectories `c/` and `asm/`. These subdirectories are no longer in use.

## Changes to global collections

Some global “collections” that were previously key elements of Ceedling have changed or gone away as the build pipeline is now able to process a configuration for each individual test executable in favor of for the entire suite.

- TODO: List collections