# Command Hooks

_Command Hooks_ is a Ceedling plugin for easily inserting command line tools at various points in the build process.

This plugin links Ceedling's general purpose plugin hooks to specific tool definitions. It allows you to skip creating a full Ceedling plugin for many common use cases.

## Use

Enable this built-in Ceedling plugin in your project file.

```yaml
:plugins:
  :enabled:
    - command_hooks
```

## Available Hooks

Define any of the following entries within the `:tools:` section of your Ceedling project file to automagically connect utilities or scripts to build process steps.

Some hooks are called for every file-related operation for which the hook is named. Other hooks are triggered by the build steps for which the hook is named.

As an example, consider a Ceedling project with ten tests and seventeen mocks. The command line `ceedling test:all` would yield:

- 1 occurrence of the `:pre_build` hook
- 10 occurrences of the `:pre_test` hook
- 17 occurrences of the `:pre_mock_generate` hook

### `:pre_build`

Called once just before Ceedling executes any tasks.

No arguments are provided when the hook is called.

### `:post_build`

Called once just before Ceedling terminates.

No arguments are provided when the hook is called.

### `:post_error`

Called once just after any build failure and just before Ceedling terminates.

No arguments are provided when the hook is called.

### `:pre_test`

Called just before each test begins its build pipeline and just after all context for that build has been gathered.

The available argument when the hook is called is the test's filepath.

### `:post_test`

Called just after each test completes its build and execution.

The available argument when the hook is called is the test's filepath.

### `:pre_release`

Called once just before a release build begins.

No arguments are provided when the hook is called.

### `:post_release`

Called once just after a release build finishes.

No arguments are provided when the hook is called.

### `:pre_mock_preprocess`

If mocks are enabled and preprocessing is in use, this is called just before each header file to be mocked is preprocessed.

The available argument when the hook is called is the filepath of the header file to be mocked.

### `:post_mock_preprocess`

If mocks are enabled and preprocessing is in use, this is called just after each header file to be mocked is preprocessed.

The available argument when the hook is called is the filepath of the header file to be mocked.

### `:pre_mock_generate`

If mocks are enabled, this is called just before each header file to be mocked is processed by mock generation.

The available argument when the hook is called is the filepath of the header file to be mocked.

### `:post_mock_generate`

If mocks are enabled, this is called just after each mock generation.

The available argument when the hook is called is the filepath of the header file to be mocked.

### `:pre_test_preprocess`

If preprocessing is in use, this is called just before each test file is preprocessed before runner generation.

The available argument when the hook is called is the test's filepath.

### `:post_test_preprocess`

If preprocessing is in use, this is called just after each test file is preprocessed.

The available argument when the hook is called is the test's filepath.

### `:pre_runner_generate`

Called just before each test file is processed by test runner generation.

The available argument when the hook is called is the test's filepath.

### `:post_runner_generate`

Called just after each test runner is generated.

The available argument when the hook is called is the test's filepath.

### `:pre_compile_execute`

Called just before each C or assembly file is compiled.

The available argument when the hook is called is the filepath of the file to be compiled.

### `:post_compile_execute`

Called just after each file compilation.

The available argument when the hook is called is the filepath of the input file that was compiled.

### `:pre_link_execute`

Called just before any binary artifact—test or release—is linked.

The available argument when the hook is called is the binary output artifact's filepath.

### `:post_link_execute`

Called just after a binary artifact is linked.

The available argument when the hook is called is the binary output artifact's filepath.

### `:pre_test_fixture_execute`

Called just before each test is executed in its corresponding test fixture.

The available argument when the hook is called is the filepath of the binary artifact to be executed by the fixture.

### `:post_test_fixture_execute`

Called just after each test's fixture is executed and test results are collected.

The available argument when the hook is called is the filepath of the binary artifact that was executed by the fixture.

## Tool Definitions

Each of the configured tools requires an `:executable` string and an optional `:arguments` list. An example follows. See Ceedling's documentation for `:tools` entries to understand how to craft your argument list and other tool options.

At present, the _Command Hooks_ plugin only passes at most one runtime info element argument for use in a tool's argument list (from among the many processed by Ceedling's plugin framework). If available, this argument can be referenced with the tool argument expansion `${1}` identifier.

```yaml
:tools:
  :pre_mock_generate: # Called every time a mock is generated
    :executable: python
    :arguments:
      - my_script.py
      - --some-arg
      - ${1} # Replaced with the file path of the header file that will be mocked
      
  :post_link_execute: # Called after each linking operation
    :executable: objcopy.exe
    :arguments:
      - ${1} # Replaced with the filepath to the linked binary artifact
      - output.srec
      - --strip-all
```

