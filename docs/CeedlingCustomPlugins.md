# Creating Custom Plugins for Ceedling

This guide walks you through the process of creating custom plugins for
[Ceedling](https://github.com/ThrowTheSwitch/Ceedling).

It is assumed that the reader has a working installation of Ceedling and some
basic usage experience, *i.e.* project creation/configuration and task running.

Some experience with Ruby and Rake will be helpful but not required.
You can learn the basics as you go, and for more complex tasks, you can browse
the internet and/or ask your preferred AI powered code generation tool ;).

<!-- TOC ignore:true -->
## Contents

<!-- TOC -->

- [Introduction](#introduction)
- [Plugin Strategies](#plugin-strategies)
	- [Configuration](#configuration)
	- [Script](#script)
		- [Setup](#setup)
		- [Mock Preprocessing](#mock-preprocessing)
		- [Test Preprocessing](#test-preprocessing)
		- [Mock Generation](#mock-generation)
		- [Test Runner Generation](#test-runner-generation)
		- [Compiling](#compiling)
		- [Linking](#linking)
		- [Test Fixture Execution](#test-fixture-execution)
		- [Test Build](#test-build)
		- [Release Build](#release-build)
		- [Ceedling Execution](#ceedling-execution)
		- [Build Failure](#build-failure)
		- [Summary](#summary)
	- [Tasks](#tasks)

<!-- /TOC -->

## Introduction

Ceedling plugins are a way to extend Ceedling without modifying its core code.
They are implemented in Ruby programming language and are loaded by Ceedling at
runtime.
Plugins provide the ability to customize the behavior of Ceedling at various
stages like preprocessing, compiling, linking, building, testing, and reporting.
They are configured and enabled from within the project's YAML configuration
file.

## Plugin Strategies

Ceedling provides 3 ways in which its behavior can be customized through a
plugin. Each strategy is implemented in a specific source file and complex
plugin behavior can be accomplished by using all strategies.

### Configuration

Provide configuration values for the project. Values are defined inside a `.yml`
file and they are merged with the loaded project configuration.

To implement this strategy, add the file `<plugin-name>.yml` to the `config`
folder of your plugin source root and add content as apropriate, just like it is
done with the `project.yml` file.

##### **`config/<plugin-name>.yml`**

```yaml
---
:plugin-name:
  :setting_1: value 1
  :setting_2: value 2
  :setting_3: value 3
  # ...
  :setting_n: value n
...
```

### Script

Perform some custom actions at various stages of the build process.

To implement this strategy, add the file `<plugin-name>.rb` to the `lib`
folder of your plugin source root. In this file you have to implement a class
for your plugin that inherits from Ceedling's plugin base class.

The `<plugin-name>.rb` file might look like this:

##### **`lib/<plugin-name>.rb`**

```ruby
require 'ceedling/plugin'

class PluginName < Plugin
  # Plugin methods
  
  # def setup()
  #   ...
  # end
end
```

It is also possible and probably convenient to add more `.rb` files to the `lib`
folder to allow organizing better the plugin source code.

The derived plugin class can define some methods which will be called by
Ceedling automatically at predefined stages of the build process.

#### Setup

Define the method `setup()` to be called as part of the project setup stage,
that is when Ceedling is loading project configuration files and setting up
everything to run project's tasks.
It can be used to perform additional project configuration or, as its name
suggests, to setup your plugin before it goes into its duties.

**Stubs**:

```ruby
class PluginName < Plugin
  def setup()
    # ...
  end
end
```

#### Mock Preprocessing

When mocks and preprocessing are enabled, define methods to be called before
(`pre_mock_preprocess()`) and after (`post_mock_preprocess()`) each header file
to be mocked is preprocessed.

**Arguments**:

```yaml
arg_hash:
  :header_file:
    Path of the header file being mocked.
  :preprocessed_header_file:
    Path of preprocessed header file.
  :test:
    Name of test file being build.
  :flags:
    Extra compiler flags for current test build.
  :include_paths: include_paths
    Include search directories for current test build.
  :defines:
    Preprocessor macros defined for current test build.
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_mock_preprocess(arg_hash)
    # ...
  end
  
  def post_mock_preprocess(arg_hash)
    # ...
  end
end
```

#### Test Preprocessing

When preprocessing is enabled, define methods to be called before
(`pre_test_preprocess()`) and after (`post_test_preprocess()`) each test file is
preprocessed.

**Arguments**:

```yaml
arg_hash:
  :test_file:
    Path of test file being build.
  :preprocessed_header_file:
    Path of preprocessed test file.
  :test:
    Name of test file being build.
  :flags:
    Extra compiler flags for current test build.
  :include_paths: include_paths
    Include search directories for current test build.
  :defines:
    Preprocessor macros defined for current test build.
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_test_preprocess(arg_hash)
    # ...
  end
  
  def post_test_preprocess(arg_hash)
    # ...
  end
end
```

#### Mock Generation

When mocks are enabled, define methods to be called before
(`pre_mock_generate()`) and after (`post_mock_generate()`) each mock generation.

**Arguments**:

```yaml
arg_hash:
  :header_file:
    Path of the header file being mocked.
  :test:
    Name of test file being build.
  :context:
    Additional context passed by the calling function.
    Ceedling passes the 'test' symbol.
  :output_path:
    Path where mock source files are saved.
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_mock_generate(arg_hash)
    # ...
  end
  
  def post_mock_generate(arg_hash)
    # ...
  end
end
```

#### Test Runner Generation

Define methods to be called before (`pre_runner_generate()`) and after
(`post_runner_generate()`) each test runner generation.

**Arguments**:

```yaml
arg_hash:
  :context:
    Additional context passed by the calling function.
    Ceedling passes the 'test' symbol.
  :test_file:
    Path of test file being build.
  :input_file:
    Path of preprocessed test file.
  :runner_file:
    Path of test runner file.
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_runner_generate(arg_hash)
    # ...
  end
  
  def post_runner_generate(arg_hash)
    # ...
  end
end
```

#### Compiling

Define methods to be called before (`pre_compile_execute()`) and after
(`post_compile_execute()`) each C or assembly file is compiled.

**Arguments**:

```yaml
arg_hash:
  # Hash holding compiler tool properties.
  :tool:
    :executable: Tool executable.
    :name: Tool name.
    :stderr_redirect: Which stderr redirect mechanism the tool uses.
    :optional: Wether tool is optional or not.
    :arguments: Arguments with which tool was called.
  :module_name:
    Source filename as module name.
    i.e. File basename.
  :operation:
    Symbol of the operation being performed.
    e.g. compile, assemble or link.
  :context:
    Additional context passed by the calling function.
    Ceedling passes a symbol according to the build type.
    e.g. 'test', 'release', 'gcov', 'bullseye', 'subprojects'.
  :source:
    Path of the input source file.
    e.g. .c file
  :object:
    Path of the output object file.
    e.g. .o file
  :search_paths:
    Include search directories for current test build.
  :flags:
    Extra compiler flags for current test build.
  :defines:
    Preprocessor macros defined for current test build.
  :list:
    Path of the listing file.
    e.g. .lst file
  :dependencies:
    Path of the dependencies file.
    e.g. .d file
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_compile_execute(arg_hash)
    # ...
  end
  
  def post_compile_execute(arg_hash)
    # ...
  end
end
```

#### Linking

Define methods to be called before (`pre_link_execute()`) and after
(`post_link_execute()`) a binary artifact is linked.

**Arguments**:

```yaml
arg_hash:
  # Hash holding linker tool properties.
  :tool:
    :executable: Tool executable.
    :name: Tool name.
    :stderr_redirect: Which stderr redirect mechanism the tool uses.
    :optional: Wether tool is optional or not.
    :arguments: Arguments with which tool was called.
  :context:
    Additional context passed by the calling function.
    Ceedling passes a symbol according to the build type.
    e.g. 'test', 'release', 'gcov', 'bullseye', 'subprojects'.
  :objects:
    List of object files paths being linked.
    e.g. .o files
  :executable:
    Path of the output file.
    e.g. .out file
  :map:
    Path of the map file.
    e.g. .map file
  :libraries:
    List of libraries to link.
    e.g. the ones passed to the linker with -l
  :libpaths:
    List of libraries paths.
    e.g. the ones passed to the linker with -L
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_link_execute(arg_hash)
    # ...
  end
  
  def post_link_execute(arg_hash)
    # ...
  end
end
```

#### Test Fixture Execution

Define methods to be called before (`pre_test_fixture_execute()`) and after
(`post_test_fixture_execute()`) each test is executed in its corresponding test
fixture.

**Arguments**:

```yaml
arg_hash:
  # Hash holding execution tool properties.
  :tool:
    :executable: Tool executable.
    :name: Tool name.
    :stderr_redirect: Which stderr redirect mechanism the tool uses.
    :optional: Wether tool is optional or not.
    :arguments: Arguments with which tool was called.
  :context:
    Additional context passed by the calling function.
    Ceedling passes a symbol according to the build type.
    e.g. 'test', 'release', 'gcov', 'bullseye', 'subprojects'.
  :executable:
    Path to the tests executable file.
    e.g. .out file
  :result_file:
    Path to the tests result file.
    e.g. .pass/.fail file
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_test_fixture_execute(arg_hash)
    # ...
  end
  
  def post_test_fixture_execute(arg_hash)
    # ...
  end
end
```

#### Test Build

Define methods to be called before (`pre_test()`) and after (`post_test()`)
each test build pipeline (configure, preprocess, compile, link, run,
get results, etc.) execution.

**Arguments**:

```yaml
test: Path of the test source file being processed.
```

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_test(test)
    # ...
  end
  
  def post_test(test)
    # ...
  end
end
```

#### Release Build

Define methods to be called before (`pre_release()`) and after (`post_release()`)
each release build pipeline (configure, preprocess, compile, link, run,
get results, etc.) execution.

**Arguments**: None.

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_release()
    # ...
  end
  
  def post_release()
    # ...
  end
end
```

#### Ceedling Execution

Define methods to be called before (`pre_build()`) and after (`post_build()`)
Ceedling executes a task.

**Arguments**: None.

**Stubs**:

```ruby
class PluginName < Plugin
  def pre_build()
    # ...
  end
  
  def post_build()
    # ...
  end
end
```

#### Build Failure

Define method to be called after any build failure and just before Ceedling
terminates.

**Arguments**: None.

**Stubs**:

```ruby
class PluginName < Plugin
  def post_error()
    # ...
  end
end
```

#### Summary

Define method to be called when invoking the `summary` task,
i.e.: `ceedling summary`.

May be used to print the plugin results of the last build.

**Arguments**: None.

**Stubs**:

```ruby
class PluginName < Plugin
  def summary()
    # ...
  end
end
```

### Tasks

Add custom Ceedling tasks to your project that can be run with
`ceedling <custom_task>`.

To implement this strategy, add the file `<plugin-name>.rake` to the plugin
source root folder and define your rake tasks inside. e.g.:

##### **`<plugin-name>.rake`**

```ruby
# Only tasks with description are listed by ceedling -T
desc "Print hello world in sh"
task :hello_world do
  sh "echo Hello World!"
end
```

The task can be called with: `ceedling hello_world`
