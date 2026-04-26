# Configuration Reference

All top-level keys of the Ceedling project configuration file, each on its own page.

<div class="grid cards" markdown>

-   **[:project — Global Project Settings][ref-project]**

    ---

    Build root, default tasks, parallelism, test preprocessor, release build
    toggle, crash backtrace, and more.

-   **[:mixins — Mixins][ref-mixins]**

    ---

    Load and merge additional YAML configuration files into your base project
    configuration for flexible, composable builds.

-   **[:test_build — Test Build Settings][ref-test-build]**

    ---

    Assembly file support for test suite builds.

-   **[:release_build — Release Build Settings][ref-release-build]**

    ---

    Output artifact name, assembly support, and additional artifact file copying.

-   **[:paths — Search Paths][ref-paths]**

    ---

    Directory path lists for source, tests, headers, support files, and libraries.
    Supports globs, subtractive entries, and inline Ruby string expansion.

-   **[:files — File Collections][ref-files]**

    ---

    Fine-grained tailoring of the file collections assembled from `:paths` —
    add or subtract individual files with globs and subtractive entries.

-   **[:environment — Environment Variables][ref-environment]**

    ---

    Define shell environment variables that are set before tools are invoked,
    with support for inline Ruby string expansion.

-   **[:extension — File Extensions][ref-extension]**

    ---

    Override the default filename extensions for source, header, object, assembly,
    executable, and other file types.

-   **[:defines — Compilation Symbols][ref-defines]**

    ---

    Add `-D` symbols to compiler command lines for release builds, all tests, or
    individual test executables matched by name, substring, or regex.

-   **[:libraries — Libraries][ref-libraries]**

    ---

    Specify test, release, and system libraries to include at link time, with
    configurable flag formats and library search paths.

-   **[:flags — Compilation & Link Flags][ref-flags]**

    ---

    Add flags to preprocessor, compiler, assembler, and linker command lines for
    release builds, all tests, or individual test executables via matchers.

-   **[:cexception — CException][ref-cexception]**

    ---

    Compile-time symbol definitions to configure CException's behavior.

-   **[:cmock — CMock][ref-cmock]**

    ---

    CMock code generation options, strict ordering, Unity helper paths, and
    compile-time symbol definitions.

-   **[:unity — Unity][ref-unity]**

    ---

    Compile-time symbol definitions to configure Unity's behavior, plus
    parameterized test case support.

-   **[:test_runner — Test Runner Generation][ref-test-runner]**

    ---

    Options passed to Unity's test runner generation script, including additional
    header includes.

-   **[:tools — Command Line Tools][ref-tools]**

    ---

    Full tool definitions for every build step: compiler, assembler, linker, and
    test fixture. Includes shortcuts for modifying built-in tools.

-   **[:plugins — Ceedling Extensions][ref-plugins]**

    ---

    Enable built-in and custom plugins, and specify additional plugin load paths.

</div>

[ref-project]:       project.md
[ref-mixins]:        mixins.md
[ref-test-build]:    test-build.md
[ref-release-build]: release-build.md
[ref-paths]:         paths.md
[ref-files]:         files.md
[ref-environment]:   environment.md
[ref-extension]:     extension.md
[ref-defines]:       defines.md
[ref-libraries]:     libraries.md
[ref-flags]:         flags.md
[ref-cexception]:    cexception.md
[ref-cmock]:         cmock.md
[ref-unity]:         unity.md
[ref-test-runner]:   test-runner.md
[ref-tools]:         tools.md
[ref-plugins]:       plugins.md
