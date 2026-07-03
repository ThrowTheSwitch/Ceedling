# Command Hooks

Easily run command line tools and scripts at various points in a Ceedling build.

## Plugin Overview

This plugin allows you to skip creating a full Ceedling plugin for many common use cases. It links Ceedling's programmatic `Plugin` code hooks to easily managed tool definitions. 

## Setup

To use this plugin, it must be enabled:

```yaml
:plugins:
  :enabled:
    - command_hooks
```

## Configuration

### Overview

To connect utilties or scripts to build step hooks, Ceedling tools must be defined.

A Ceedling tool is just a YAML blob that gathers together a handful of settings and values that tell Ceedling how to build and execute a command line. Your tool can be a command line utility, a script, etc.

Example Ceedling tools follow. When enabled, this plugin ensures any tools you define are executed by the corresponding build step hook they are organized beneath. The configurtion of enabled hooks and tools happens in a top-level `:command_hooks:` block within your project configuration. One or more tools can be attached to a build step hook.

### Tool lists

A command hook can execute one or more tools.

If only a single tool is needed, its hash keys and value can be organized as a YAML sub-hash beneath the hook key. Alternatively, a single tool can exist as the only entry in a YAML list.

If multiple tools are needed, they must be organized as entries in a YAML list.

See the commented examples below.

### Tool definitions

Each Ceedling tool requires an `:executable` string and an optional `:arguments` list. See the [`:tools` configuration reference][tools-doc] to understand how to craft your argument list and other tool options.

This plugin passes one or two runtime parameters for use in a hook's tool argument list depending on the hook. These parameters are referenced with Ceedling tool argument expansion identifiers `${1}`, `${2}`, etc. Wherever you place `${1}` or `${2}` in your tool argument list, they expand in the command line Ceedling constructs with the parameters this plugin provides for that build step hook. The list of build step hooks below documents which parameters are available for each hook.

[tools-doc]: ../configuration/reference/tools.md

### Hook logging

In addition to the standard Ceedling tool definition elements, a hook configuration entry may optionally include a `:logging` setting.

`:logging` may be set to `TRUE` or `FALSE`. An omitted setting is equivalent to `FALSE`.

When logging is enabled and logging conditions are appropriate, any output from the hook tool will be logged to the console with a brief header identifying the hook.

* Explicit command hook output logging only occurs at verbosity levels Normal and Obnoxious.
* Debug logging naturally displays hook output as part of normal tool execution logging. It is not duplicated by hook logging.
* At Normal verbosity, blank hook output is not logged at all; Obnoxious verbosity will display blank output as `<empty>`.

### Command Hooks example configuration YAML

```yaml
:command_hooks:
  # Hook called every time a mock is generated
  # Who knows what my_script.py does -- sky is the limit
  :pre_mock_generate:
    # This tool is organized as a sub-hash beneath the command hook key
    :executable: python
    :arguments:
      - my_script.py
      - --some-arg
      - ${1} # Replaced with the filepath of the header file that will be mocked
    :logging: TRUE # Log any tool output to console
      
  # Hook called for each linking operation
  # Here, we are performing two tasks for the same build step hook, converting a
  # binary executable to S-record format and, then, archiving with other artifacts.
  :post_link_execute:
    # These tools are organized in a YAML list beneath the command hook key
    - :executable: objcopy.exe
      :arguments:
        - ${1} # Replaced with the filepath to the linker's binary artifact output
        - output.srec
        - --strip-all
    - :executable: 
      :arguments: tar.exe
        - -acf
        - awesome_build.zip
        - ${1} # Replaced with the filepath to the linker's binary artifact output
        - memory_report.txt
```

## Available Build Step Hooks

Define any of the following entries within a top-level `:command_hooks:` section of your Ceedling project file to automagically connect utilities or scripts to build process steps.

Some hooks are called for every file-related operation for which the hook is named. Other hooks are triggered by the single build step for which the hook is named.

As an example, consider a Ceedling project with ten test files and seventeen mocks. The command line `ceedling test:all` would trigger:

* 1 occurrence of the `:pre_build` hook.
* 1 occurrence of the `:pre_test_build` hook.
* 10 occurrences of the `:pre_test` and `:post_test` hooks.
* 17 occurrences of the `:pre_mock_generate` and `:post_mock_generate` hooks.
* 10 occurrences of the `:pre_test_runner_generate` and `:post_test_runner_generate` hooks.
* 27(+) occurrences of the `:pre_compile` and `:post_compile` hooks. These hooks would be called 27 times for test file and mock file compilation. A test suite build will also include compilation of the source files under tests, Unity's source, CMock's source, and generated test runner C files -- easily more than another two dozen compilation hook calls.
* 10 occurrences of the `:pre_link` and `:post_link` hooks for test executable creation.
* 10 occurrences of the `:pre_test_fixture_execute` and `:post_test_fixture_execute` hooks for running test executables and gathering the results of the tests cases they contain.
* 1 occurrence of the `:post_test_build` hook.
* 1 occurrence of the `:post_build` hook unless a build error occurred (`:post_error` would be called instead).

### `:pre_build`

Called once just before Ceedling executes any tasks.

The parameter available to a tool (`${1}`) when the hook is called is a floating-point stopwatch value in seconds. This value and the corresponding `post_build` value can be used to compute the total build duration.

### `:post_build`

Called once just before Ceedling terminates after a successful build.

The parameter available to a tool (`${1}`) when the hook is called is a floating-point stopwatch value in seconds. This value and the corresponding `pre_build` value can be used to compute the total build duration.

### `:post_error`

Called once just after any build failure and just before Ceedling terminates.

The parameter available to a tool (`${1}`) when the hook is called is a floating-point stopwatch value in seconds at the moment the error is handled.

### `:pre_test`

Called just before each test begins its build pipeline and just after all context for that build has been gathered.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

### `:post_test`

Called just after each test completes its build and execution.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

### `:pre_test_build`

Called once just before the full test build pipeline begins (before any individual test's configure, preprocess, compile, link, or execute steps).

Two parameters are available to a tool when the hook is called:

* `${1}` — the build context as a string (e.g. `"test"`, `"gcov"`).
* `${2}` — a floating-point stopwatch value in seconds. This value and the corresponding `post_test_build` value can be used to compute the total test build duration.

### `:post_test_build`

Called once just after the full test build pipeline completes or terminates (including on error).

Two parameters are available to a tool when the hook is called:

* `${1}` — the build context as a string (e.g. `"test"`, `"gcov"`).
* `${2}` — a floating-point stopwatch value in seconds. This value and the corresponding `pre_test_build` value can be used to compute the total test build duration.

### `:pre_release_build`

Called once just before a release build begins.

The parameter available to a tool (`${1}`) when the hook is called is a floating-point stopwatch value in seconds. This value and the corresponding `post_release_build` value can be used to compute the total release build duration.

### `:post_release_build`

Called once just after a release build finishes or terminates (including on error).

The parameter available to a tool (`${1}`) when the hook is called is a floating-point stopwatch value in seconds. This value and the corresponding `pre_release_build` value can be used to compute the total release build duration.

### `:pre_mock_preprocess`

If mocks are enabled and preprocessing is in use, this is called just before each header file to be mocked is preprocessed.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

See [_Conventions & Behaviors_][preprocessing] for details on how Ceedling preprocessing operates.

[preprocessing]: ../testing-guide/conventions.md#test-preprocessing

### `:post_mock_preprocess`

If mocks are enabled and preprocessing is in use, this is called just after each header file to be mocked is preprocessed.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

### `:pre_mock_generate`

If mocks are enabled, this is called just before each header file to be mocked is processed by mock generation.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

### `:post_mock_generate`

If mocks are enabled, this is called just after each mock generation.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

### `:pre_test_preprocess`

If preprocessing is in use, this is called just before each test file is preprocessed before runner generation.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

See [_Conventions & Behaviors_][preprocessing] for details on how Ceedling preprocessing operates.

### `:post_test_preprocess`

If preprocessing is in use, this is called just after each test file is preprocessed.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

See [_Conventions & Behaviors_][preprocessing] for details on how Ceedling preprocessing operates.

### `:pre_runner_generate`

Called just before each test file is processed by test runner generation.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

### `:post_runner_generate`

Called just after each test runner is generated.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

### `:pre_compile_execute`

Called just before each C or assembly file is compiled.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the file to be compiled.

### `:post_compile_execute`

Called just after each file compilation.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the input file that was compiled.

### `:pre_link_execute`

Called just before any binary artifact—test or release—is linked.

The parameter available to a tool (`${1}`) when the hook is called is the binary output artifact's filepath.

### `:post_link_execute`

Called just after a binary artifact is linked.

The parameter available to a tool (`${1}`) when the hook is called is the binary output artifact's filepath.

### `:pre_test_fixture_execute`

Called just before each test is executed in its corresponding test fixture.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the binary artifact to be executed by the fixture.

### `:post_test_fixture_execute`

Called just after each test's fixture is executed and test results are collected.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the binary artifact that was executed by the fixture.

<br/><br/>
