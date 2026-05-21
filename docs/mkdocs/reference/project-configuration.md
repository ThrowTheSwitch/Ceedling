# Project Configuration Reference

Ceedling's project configuration is assembled from one or more sources and
merged into a single in-memory data structure before any build begins. The
base configuration comes from a YAML project file. That base can be extended
by [Mixins](../configuration/reference/mixins.md) — additional YAML files
merged in after the base is loaded. Mixins can be specified from the command
line, via environment variables, or from within the project file using the
`:mixins:` section listed below.

For the full details on how loading and merging work — including the search
order for the default project file and all Mixin sources — see
[Loading Configuration](../configuration/loading.md). For the environment
variables that influence configuration loading, see
[Environment Variables](../configuration/environment-vars.md).

For conceptual overview and project file conventions, see
[Configuration](../configuration/index.md).

## Configuration sections

Each top-level key in your project YAML file corresponds to one configuration
section. All sections are optional; Ceedling supplies defaults for anything
left unset.

| Section | Description |
|---|---|
| **[`:project`](../configuration/reference/project.md)** | Build root, build modes, version info, and global project switches |
| **[`:mixins`](../configuration/reference/mixins.md)** | Load and merge additional YAML configuration files into the base project configuration |
| **[`:test_build`](../configuration/reference/test-build.md)** | Test-specific build options: assembly support, mock generation, preprocessor use, and more |
| **[`:release_build`](../configuration/reference/release-build.md)** | Release artifact build options and output settings |
| **[`:paths`](../configuration/reference/paths.md)** | Source, test, include, support, library, and vendor path globs |
| **[`:files`](../configuration/reference/files.md)** | Explicit file inclusion and exclusion overrides |
| **[`:environment`](../configuration/reference/environment.md)** | Set and export environment variables from within the project configuration |
| **[`:extension`](../configuration/reference/extension.md)** | File extension strings for source, header, object, binary, and other file types |
| **[`:defines`](../configuration/reference/defines.md)** | Per-context, per-file preprocessor symbol definitions |
| **[`:flags`](../configuration/reference/flags.md)** | Compiler, linker, assembler, and preprocessor flags per build context |
| **[`:libraries`](../configuration/reference/libraries.md)** | Test and release libraries plus linker search paths |
| **[`:unity`](../configuration/reference/unity.md)** | Unity test framework configuration (defines, helper file paths, etc.) |
| **[`:cmock`](../configuration/reference/cmock.md)** | CMock mock generation configuration |
| **[`:test_runner`](../configuration/reference/test-runner.md)** | Test runner generation configuration |
| **[`:cexception`](../configuration/reference/cexception.md)** | CException configuration |
| **[`:plugins`](../configuration/reference/plugins.md)** | Enable built-in plugins and configure custom plugin load paths |
| **[`:tools`](../configuration/reference/tools.md)** | Define or override compiler, linker, and other tool invocations |

<br/><br/>
