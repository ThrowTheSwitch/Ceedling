# Ceedling Plugin: Command Hooks

Easily run command line tools and scripts at various points in a Ceedling build.

# Plugin Overview

This plugin allows you to skip creating a full Ceedling plugin for many common use cases. It links Ceedling's programmatic `Plugin` code hooks to easily managed tool definitions. 

# Setup

To use this plugin, it must be enabled:

```yaml
:plugins:
  :enabled:
    - command_hooks
```

# Configuration

To connect a utilties or scripts to build step hooks, Ceedling tools must be defined.

A Ceedling tool is just a YAML blob that gathers together a handful of settings and values that tell Ceedling how to build and execute a command line. Your tool can be a command line utility, a script, etc.

Example Ceedling tools follow. Their tool entry names correspond to the build step hooks listed later in this document. That's how this plugin works. When enabled, it ensures any tools you define are executed by the corresponding build step hook that shares their name.

Each Ceedling tool requires an `:executable` string and an optional `:arguments` list. See _[CeedlingPacket][ceedling-packet]_ documentation for `:tools` entries to understand how to craft your argument list and other tool options.

At present, this plugin only passes at most one runtime parameter for a given build step hook for use in a tool's argument list (from among the many processed by Ceedling's plugin framework). If available, this parameter can be referenced with a Ceedling tool argument expansion identifier `${1}`. That is, wherever you place `${1}` in your tool argument list, `${1}` will expand in the command line Ceedling constructs with the parameter this plugin provides for that build step hook. The list of build steps hooks below document any single parameters they provide at execution.

```yaml
:tools:
  # Called every time a mock is generated
  # Who knows what my_script.py does -- sky is the limit
  :pre_mock_generate:
    :executable: python
    :arguments:
      - my_script.py
      - --some-arg
      - ${1} # Replaced with the filepath of the header file that will be mocked
      
  # Called after each linking operation
  # Here, we are converting a binary executable to S-record format
  :post_link_execute:
    :executable: objcopy.exe
    :arguments:
      - ${1} # Replaced with the filepath to the linker's binary artifact output
      - output.srec
      - --strip-all
```

# Available Build Step Hooks

Define any of the following entries within the `:tools:` section of your Ceedling project file to automagically connect utilities or scripts to build process steps.

Some hooks are called for every file-related operation for which the hook is named. Other hooks are triggered by single build step for which the hook is named.

As an example, consider a Ceedling project with ten test files and seventeen mocks. The command line `ceedling test:all` would trigger:

* 1 occurrence of the `:pre_build` hook.
* 10 occurrences of the `:pre_test` and `:post_test` hooks.
* 17 occurrences of the `:pre_mock_generate` and `:post_mock_generate` hooks.
* 10 occurrences of the `:pre_test_runner_generate` and `:post_test_runner_generate` hooks.
* 27(+) occurrences of the `:pre_compile` and `:post_compile` hooks. These hooks would be called 27 times for test file and mock file compilation. A test suite build will also include compilation of the source files under tests, Unity's source, CMock's source, and generated test runner C files -- easily more than another two dozen compilation hook calls.
* 10 occurrences of the `:pre_link` and `:post_link` hooks for test executable creation.
* 10 occurences of the `:pre_test_fixture_execute` and `:post_test_fixture_execute` hooks for running test executables and gathering the results of the tests cases they contain.
* 1 occurence of the `:post_build` hook unless a build error occurred (`:post_error` would be called isntead).

## `:pre_build`

Called once just before Ceedling executes any tasks.

No parameters are provided for a tool's argument list when the hook is called.

## `:post_build`

Called once just before Ceedling terminates.

No parameters are provided for a tool's argument list when the hook is called.

## `:post_error`

Called once just after any build failure and just before Ceedling terminates.

No parameters are provided for a tool's argument list when the hook is called.

## `:pre_test`

Called just before each test begins its build pipeline and just after all context for that build has been gathered.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

## `:post_test`

Called just after each test completes its build and execution.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

## `:pre_release`

Called once just before a release build begins.

No parameters are provided for a tool's argument list when the hook is called.

## `:post_release`

Called once just after a release build finishes.

No parameters are provided for a tool's argument list when the hook is called.

## `:pre_mock_preprocess`

If mocks are enabled and preprocessing is in use, this is called just before each header file to be mocked is preprocessed.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

See _[CeedlingPacket][ceedling-packet]_ for details on how Ceedling preprocessing operates.

[ceedling-packet]: ../docs/CeedlingPacket.md

## `:post_mock_preprocess`

If mocks are enabled and preprocessing is in use, this is called just after each header file to be mocked is preprocessed.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

## `:pre_mock_generate`

If mocks are enabled, this is called just before each header file to be mocked is processed by mock generation.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

## `:post_mock_generate`

If mocks are enabled, this is called just after each mock generation.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the header file to be mocked.

## `:pre_test_preprocess`

If preprocessing is in use, this is called just before each test file is preprocessed before runner generation.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

See _[CeedlingPacket][ceedling-packet]_ for details on how Ceedling preprocessing operates.

## `:post_test_preprocess`

If preprocessing is in use, this is called just after each test file is preprocessed.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

See _[CeedlingPacket][ceedling-packet]_ for details on how Ceedling preprocessing operates.

## `:pre_runner_generate`

Called just before each test file is processed by test runner generation.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

## `:post_runner_generate`

Called just after each test runner is generated.

The parameter available to a tool (`${1}`) when the hook is called is the test's filepath.

## `:pre_compile_execute`

Called just before each C or assembly file is compiled.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the file to be compiled.

## `:post_compile_execute`

Called just after each file compilation.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the input file that was compiled.

## `:pre_link_execute`

Called just before any binary artifact—test or release—is linked.

The parameter available to a tool (`${1}`) when the hook is called is the binary output artifact's filepath.

## `:post_link_execute`

Called just after a binary artifact is linked.

The parameter available to a tool (`${1}`) when the hook is called is the binary output artifact's filepath.

## `:pre_test_fixture_execute`

Called just before each test is executed in its corresponding test fixture.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the binary artifact to be executed by the fixture.

## `:post_test_fixture_execute`

Called just after each test's fixture is executed and test results are collected.

The parameter available to a tool (`${1}`) when the hook is called is the filepath of the binary artifact that was executed by the fixture.
