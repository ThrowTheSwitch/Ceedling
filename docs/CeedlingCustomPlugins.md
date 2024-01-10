# Creating Custom Plugins for Ceedling

This guide walks you through the process of creating custom plugins for
[Ceedling](https://github.com/ThrowTheSwitch/Ceedling).

It is assumed that the reader has a working installation of Ceedling and some
basic usage experience, *i.e.* project creation/configuration and task running.

Some experience with Ruby and Rake will be helpful but not required.
You can learn the basics as you go, and for more complex tasks, you can browse
the internet and/or ask your preferred AI powered code generation tool ;).

## Table of Contents
- [Introduction](#introduction)
- [Ceedling Plugin Architecture](#ceedling-plugin-architecture)
  - [Configuration](#configuration)
  - [Script](#script)
  - [Rake Tasks](#rake-tasks)

## Introduction

Ceedling plugins are a way to extend Ceedling without modifying its core code.
They are implemented in Ruby programming language and are loaded by Ceedling at
runtime.
Plugins provide the ability to customize the behavior of Ceedling at various
stages like preprocessing, compiling, linking, building, testing, and reporting.
They are configured and enabled from within the project's YAML configuration
file.

## Ceedling Plugin Architecture

Ceedling provides 3 ways in which its behavior can be customized through a
plugin. Each strategy is implemented in a specific source file.

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
  def setup
    # ...
  end
  
  def pre_test(test)
    # ...
  end
  
  def post_test(test)
    # ...
  end
end
```

It is also possible and probably convenient to add more `.rb` files to the `lib`
folder to allow organizing better the plugin source code.

The derived plugin class can define some methods which will be called by
Ceedling automatically at predefined stages of the build process.

#### `setup`

This method is called as part of the project setup stage, that is when Ceedling
is loading project configuration files and setting up everything to run
project's tasks.
It can be used to perform additional project configuration or, as its name
suggests, to setup your plugin for subsequent runs.

#### `pre_mock_generate(arg_hash)` and `post_mock_generate(arg_hash)`

These methods are called before and after execution of mock generation tool
respectively.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Path of the header file being mocked.
  :header_file => "<header file being mocked>",
  # Additional context passed by the calling function.
  # Ceedling passes the 'test' symbol.
  :context => TEST_SYM
}
```

#### `pre_runner_generate(arg_hash)` and `post_runner_generate(arg_hash)`

These methods are called before and after execution of the Unity's test runner
generator tool respectively.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Additional context passed by the calling function.
  # Ceedling passes the 'test' symbol.
  :context => TEST_SYM,
  # Path of the tests source file.
  :test_file => "<tests source file>",
  # Path of the tests runner file.
  :runner_file => "<tests runner source file>"
}
```

#### `pre_compile_execute(arg_hash)` and `post_compile_execute(arg_hash)`

These methods are called before and after source file compilation respectively.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
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

#### `pre_link_execute(arg_hash)` and `post_link_execute(arg_hash)`

These methods are called before and after linking the executable file
respectively.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
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

#### `pre_test_fixture_execute(arg_hash)` and `post_test_fixture_execute(arg_hash)`

These methods are called before and after running the tests executable file
respectively.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
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

#### `pre_test(test)` and `post_test(test)`

These methods are called before and after performing all steps needed to run a
test file respectively, i.e. configure, preprocess, compile, link, run, get
results, etc.

The argument `test` corresponds to the path of the test source file being
processed.

#### `pre_release` and `post_release`

These methods are called before and after performing all steps needed to run the
release task respectively, i.e. configure, preprocess, compile, link, etc.

#### `pre_build` and `post_build`

These methods are called before and after executing any ceedling task
respectively. e.g: test, release, coverage, etc.

#### `post_error`

This method is called in case an error happens during project build process.

#### `summary`

This method is called when onvoking the `summary` task, i.e.: `ceedling summary`.
The idea is that the method prints the results of the last build.

### Rake Tasks

Add custom Rake tasks to your project that can be run with
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
