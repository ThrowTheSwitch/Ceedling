---
toc_depth: 3
---

# Configuration

!!! tip "Annotated Sample Configuration"
    See the [annotated sample project configuration file](../snapshot/assets/project.yml)
    for a commented example of available settings.

## Loading & Basics

<div class="grid cards" markdown>

-   **[How to Load a Project Configuration][configuration-loading]**

    ---

    Load your base configuration via command line flag, environment variable, or
    default file. Add Mixins to merge additional configuration for different
    build scenarios.

-   **[Project Configuration File Basics][project-file]**

    ---

    YAML conventions, project file structure, and special Ceedling-specific YAML
    handling.

</div>

## Advanced Topics

<div class="grid cards" markdown>

-   **[Which Ceedling][which-ceedling]**

    ---

    Sometimes you may need to point to a different Ceedling to run.

-   **[Global Collections][global-collections]**

    ---

    Globally available Ruby lists of paths, files, and more — useful for advanced
    project customization and plugin development.

</div>

## Configuration Reference

All top-level keys of the Ceedling project configuration file, each documented on its own page.

### Project & Build Structure

<div class="grid cards" markdown>

-   **[`:project` Global Project Settings][ref-project]**

    ---

    Build root, default tasks, parallelism, test preprocessing, release build
    toggle, crash backtrace, and more.

-   **[`:mixins` Mixins][ref-mixins]**

    ---

    Load and merge additional YAML configuration files into your base project
    configuration for flexible, composable builds.

-   **[`:test_build` Test Build Settings][ref-test-build]**

    ---

    Assembly file support for test suite builds.

-   **[`:release_build` Release Build Settings][ref-release-build]**

    ---

    Output artifact name, assembly support, and additional artifact file copying.

-   **[`:environment` Environment Variables][ref-environment]**

    ---

    Define shell environment variables that are set before tools are invoked,
    with support for inline Ruby string expansion.

</div>

### Files, Paths & Extensions

<div class="grid cards" markdown>

-   **[`:paths` Search Paths][ref-paths]**

    ---

    Directory path lists for source, tests, headers, support files, and libraries.
    Supports globs, subtractive entries, and inline Ruby string expansion.

-   **[`:files` File Collections][ref-files]**

    ---

    Fine-grained tailoring of the file collections assembled from `:paths` —
    add or subtract individual files with globs and subtractive entries.

-   **[`:extension` File Extensions][ref-extension]**

    ---

    Override the default filename extensions for source, header, object, assembly,
    executable, and other file types.

</div>

### Compilation & Linking

<div class="grid cards" markdown>

-   **[`:defines` Compilation Symbols][ref-defines]**

    ---

    Add `-D` symbols to compiler command lines for release builds, all tests, or
    individual test executables matched by name, substring, or regex.

-   **[`:flags` Compile & Link Flags][ref-flags]**

    ---

    Add flags to preprocessor, compiler, assembler, and linker command lines for
    release builds, all tests, or individual test executables via matchers.

-   **[`:libraries` Libraries][ref-libraries]**

    ---

    Specify test, release, and system libraries to include at link time, with
    configurable flag formats and library search paths.

</div>

### Frameworks

<div class="grid cards" markdown>

-   **[`:unity` Unity][ref-unity]**

    ---

    Compile-time symbol definitions to configure Unity's behavior, plus
    parameterized test case support.

-   **[`:cmock` CMock][ref-cmock]**

    ---

    CMock code generation options, strict ordering, Unity helper paths, and
    compile-time symbol definitions.

-   **[`:cexception` CException][ref-cexception]**

    ---

    Compile-time symbol definitions to configure CException's behavior.

-   **[`:test_runner` Test Runner Generation][ref-test-runner]**

    ---

    Options passed to Unity's test runner generation script, including additional
    header includes.

</div>

### Tools & Extensions

<div class="grid cards" markdown>

-   **[`:tools` Command Line Tools][ref-tools]**

    ---

    Full tool definitions for every build step: compiler, assembler, linker, and
    test fixture. Includes shortcuts for modifying built-in tools.

-   **[`:plugins` Ceedling Extensions][ref-plugins]**

    ---

    Enable built-in and custom plugins, and specify additional plugin load paths.

</div>

[configuration-loading]:  ../configuration-loading.md
[project-file]:           project-file.md
[which-ceedling]:         ../which-ceedling.md
[global-collections]:     ../global-collections.md

[ref-project]:       reference/project.md
[ref-mixins]:        reference/mixins.md
[ref-test-build]:    reference/test-build.md
[ref-release-build]: reference/release-build.md
[ref-paths]:         reference/paths.md
[ref-files]:         reference/files.md
[ref-environment]:   reference/environment.md
[ref-extension]:     reference/extension.md
[ref-defines]:       reference/defines.md
[ref-libraries]:     reference/libraries.md
[ref-flags]:         reference/flags.md
[ref-cexception]:    reference/cexception.md
[ref-cmock]:         reference/cmock.md
[ref-unity]:         reference/unity.md
[ref-test-runner]:   reference/test-runner.md
[ref-tools]:         reference/tools.md
[ref-plugins]:       reference/plugins.md
