
# 💔 Breaking Changes for 0.32 Release Candidate

**Version:** 0.32 pre-release incremental build

**Date:** February 22, 2024

# Explicit `:paths` ↳ `:include` entries in the project file

The `:paths` ↳ `:include` entries in the project file must now be explicit and complete.

Eaerlier versions of Ceedling were rather accomodating when assembling the search paths for header files. The full list of directories was pulled from multiple `:paths` entries with de-duplication. If you had header files in your `:source` directories but did not explicitly list those directories in your `:include` paths, Ceedling would helpfully figure it out and use all the paths.

This behavior is no more. Why? For two interrelated reasons.

1. For large or complex projects, expansive header file search path lists can exceed command line maximum lengths on some platforms. An enforced, tailored set of search paths helps prevent this problem.
1. In order to support the desired behavior of `TEST_INCLUDE_PATH()` a concice set of “base” header file search paths is necessary. `:paths` ↳ `:include` is that base list.

Using 0.32 Ceedling with older project files can lead to errors when generating mocks or compiler errors on finding header files. Add all paths to the `:paths` ↳ `:include` project file entry to fix this problem.

# Format change for `:defines` in the project file

To better support per-test-executable configurations, the format of `:defines` has changed. See the [official documentation](CeedlingPacket.md) for specifics.

In brief:

1. A more logically named hierarchy differentiates `#define`s for test preprocessing, test compilation, and release compilation.
1. Previously, compilation symbols could be specified for a specific C file by name, but these symbols were only defined when compiling that specific file. Further, this matching was only against a file's full name. Now, pattern matching is also an option.
1. Filename matching for test compilation symbols happens against _only test file names_. More importantly, the configured symbols are applied in compilation of each C file that comprises a test executable. Each test executable is treated as a mini-project.

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

# Raw Output Report Plugin

This plugin (renamed -- see next section) no longer generated empty log files and no longer generates log files with _test_ and _pass_ in their filenames. Log files are now simply named `<test file>.raw.log`.

# Plugin Name Changes

The following plugin names will need to be updated in the `:plugins` section of your `project.yml` file.

- The plugin previously called `fake_function_framework` is now simply called `fff`.
- `json_tests_report`, `xml_tests_report`, and `junit_tests_report` have been superseded by a single plugin `test_suite_reporter` able to generate each of the previous test reports as well as user-defined tests reports.
- `raw_output_report` has been renamed to `raw_tests_output_report`.

# Subprojects Plugin Replaced

The `subprojects` plugin has been completely replaced by the more-powerful `dependencies` plugin. To retain your previous functionality, you need to do a little reorganizing in your `project.yml` file. Obviously the `:subprojects` section is now called `:dependencies`. The collection of `:paths` is now `:deps`. We'll have a little more organizing to do once we're inside that section as well. Your `:source` is now organized in `:source_path` and, since you're not fetching it form another project, the `:fetch:method` should be set to `:none`. The `:build_root` now becomes `:build_path`. You'll also need to specify the name of the library produced under `:artifacts:static_libraries`.

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
      :source_path:   ./subprojectA/
      :build_path:    ./subprojectA/
      :artifact_path: ./subprojectA/build/dir
      :fetch:
        :method: :none
      :environment: []
      :build:
        - :deps_compiler
        - :deps_linker
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