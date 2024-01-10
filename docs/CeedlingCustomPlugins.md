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

**Example**:

```ruby
class PluginName < Plugin
  def setup()
    # ...
  end
end
```

#### Mock Preprocessing

_Note: Ceedling v0.32_

When mocks and preprocessing are enabled, define methods to be called before
(`pre_mock_preprocess()`) and after (`post_mock_preprocess()`) each header file
to be mocked is preprocessed.

**Arguments**:

- `arg_hash`:
  ```ruby
  {
    
  }
  ```

**Example**:

```ruby
class PluginName < Plugin
  def pre_mock_preprocess(arg_hash)
    # ...
  end
  
  def post_mock_preprocess(args_hash)
    # ...
  end
end
```

#### Test Preprocessing

_Note: Ceedling v0.32_

When preprocessing is enabled, define methods to be called before
(`pre_test_preprocess()`) and after (`post_test_preprocess()`) each test file is
preprocessed.

**Arguments**:

- `arg_hash`:
  ```ruby
  {
    
  }
  ```

**Example**:

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

- `arg_hash`:
  ```ruby
  {
    # Path of the header file being mocked.
    :header_file => "<header file being mocked>",
    # Additional context passed by the calling function.
    # Ceedling passes the 'test' symbol.
    :context => TEST_SYM
  }
  ```

**Example**:

```ruby
class PluginName < Plugin
  def pre_mock_generate(arg_hash)
    # ...
  end
  
  def post_mock_generate(args_hash)
    # ...
  end
end
```

#### Test Runner Generation

Define methods to be called before (`pre_runner_generate()`) and after
(`post_runner_generate()`) each test runner generation.

**Arguments**:

- `arg_hash`:
  ```ruby
  {
    # Additional context passed by the calling function.
    # Ceedling passes the 'test' symbol.
    :context => TEST_SYM,
    # Path of the tests source file.
    :test_file => "<tests source file>",
    # Path of the tests runner file.
    :runner_file => "<tests runner source file>"
  }
  ```

**Example**:

```ruby
class PluginName < Plugin
  def pre_runner_generate(arg_hash)
    # ...
  end
  
  def post_runner_generate(args_hash)
    # ...
  end
end
```

#### Compiling

Define methods to be called before (`pre_compile_execute()`) and after
(`post_compile_execute()`) each C or assembly file is compiled.

**Arguments**:

- `arg_hash`:
  ```ruby
  {
    # Hash holding compiler tool properties.
    :tool => {
      :executable => "<tool executable>",
      :name => "<tool name>",
      :stderr_redirect => StdErrRedirect::NONE,
      :optional => false,
      :arguments => [],
    },
    # Symbol of the operation being performed, i.e.: compile, assemble or link
    :operation => OPERATION_COMPILE_SYM,
    # Additional context passed by the calling function.
    # Ceedling passes a symbol according to the build type.
    # e.g.: 'test', 'release', 'gcov', 'bullseye', 'subprojects'.
    :context => TEST_SYM,
    # Path of the input source file. e.g.: .c file
    :source => "<source file>",
    # Path of the output object file. e.g.: .o file
    :object => "<object file>",
    # Path of the listing file. e.g.: .lst file
    :list => "<listing file>",
    # Path of the dependencies file. e.g.: .d file
    :dependencies => "<dependencies file>"
  }
  ```

**Example**:

```ruby
class PluginName < Plugin
  def pre_compile_execute(arg_hash)
    # ...
  end
  
  def post_compile_execute(args_hash)
    # ...
  end
end
```

#### Linking

Define methods to be called before (`pre_link_execute()`) and after
(`post_link_execute()`) a binary artifact is linked.

**Arguments**:

- `arg_hash`:
  ```ruby
  {
    # Hash holding linker tool properties.
    :tool => {
      :executable => "<tool executable>",
      :name => "<tool name>",
      :stderr_redirect => StdErrRedirect::NONE,
      :optional => false,
      :arguments => [],
    },
    # Additional context passed by the calling function.
    # Ceedling passes a symbol according to the build type.
    # e.g.: 'test', 'release', 'gcov', 'bullseye', 'subprojects'.
    :context => TEST_SYM,
    # List of object files paths being linked. e.g.: .o files
    :objects => [],
    # Path of the output file. e.g.: .out file
    :executable => "<executable file>",
    # Path of the map file. e.g.: .map file
    :map => "<map file>",
    # List of libraries to link. e.g.: the ones passed to the linker with -l
    :libraries => [],
    # List of libraries paths. e.g.: the ones passed to the linker with -L
    :libpaths => []
  }
  ```

**Example**:

```ruby
class PluginName < Plugin
  def pre_link_execute(arg_hash)
    # ...
  end
  
  def post_link_execute(args_hash)
    # ...
  end
end
```

#### Test Fixture Execution

Define methods to be called before (`pre_test_fixture_execute()`) and after
(`post_test_fixture_execute()`) each test is executed in its corresponding test
fixture.

**Arguments**:

- `arg_hash`:
  ```ruby
  {
    # Hash holding execution tool properties.
    :tool => {
      :executable => "<tool executable>",
      :name => "<tool name>",
      :stderr_redirect => StdErrRedirect::NONE,
      :optional => false,
      :arguments => [],
    },
    # Additional context passed by the calling function.
    # Ceedling passes a symbol according to the build type.
    # e.g.: 'test', 'release', 'gcov', 'bullseye', 'subprojects'.
    :context => TEST_SYM,
    # Path to the tests executable file. e.g.: .out file
    :executable => "<executable file>",
    # Path to the tests result file. e.g.: .pass/.fail file
    :result_file => "<result file>"
  }
  ```

**Example**:

```ruby
class PluginName < Plugin
  def pre_test_fixture_execute(arg_hash)
    # ...
  end
  
  def post_test_fixture_execute(args_hash)
    # ...
  end
end
```

#### Test Build

Define methods to be called before (`pre_test()`) and after (`post_test()`)
each test build pipeline (configure, preprocess, compile, link, run,
get results, etc.) execution.

**Arguments**:

- `test`: Path of the test source file being processed.

**Example**:

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

**Example**:

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

**Example**:

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

**Example**:

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

**Example**:

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
