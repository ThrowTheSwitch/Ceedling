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
- [Choosing a Plugin Idea](#choosing-a-plugin-idea)
- [Creating a Plugin Skeleton](#creating-a-plugin-skeleton)
- [Implementing Plugin Logic](#implementing-plugin-logic)
- [Testing the Plugin](#testing-the-plugin)
- [Packaging and Distributing the Plugin](#packaging-and-distributing-the-plugin)
- [Conclusion](#conclusion)

## Introduction

Ceedling plugins are a way to extend Ceedling without modifying its core code.
They are implemented in Ruby programming language and are loaded by Ceedling at
runtime.
Plugins provide the ability to customize the behavior of Ceedling at various
stages like preprocessing, compiling, linking, building, testing, and reporting.
They are configured and enabled from within the project's YAML configuration file.

## Ceedling Plugin Architecture

Ceedling provides 3 ways in which its behavior can be customized through a plugin.
Each strategy is implemented in a specific source file.

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
for your plugin that inherits from Ceedling's plugin base class. e.g.:

```ruby
require 'ceedling/plugin'

class PluginName < Plugin
#  ...
end
```

There are some methods that the class can define which will be called by
Ceedling automatically at predefined stages of the build process.
These are:

#### `setup`

This method is called as part of the project setup stage, that is when Ceedling
is loading project configuration files and setting up everything to run
project's tasks.
It can be used to perform additional project configuration or, as its name
suggests, to setup your plugin for subsequent runs.

#### `pre_mock_generate(arg_hash)` and `post_mock_generate(arg_hash)`

These methods are called before and after execution of mock generation tool
respectively.

The argument `arg_hash` is as follows:

```ruby
arg_hash = {}
```

#### `pre_runner_generate(arg_hash)` and `post_runner_generate(arg_hash)`



#### `pre_compile_execute(arg_hash)` and `post_compile_execute(arg_hash)`



#### `pre_link_execute(arg_hash)` and `post_link_execute(arg_hash)`



#### `pre_test_fixture_execute(arg_hash)` and `post_test_fixture_execute(arg_hash)`



#### `pre_test(test)` and `post_test(test)`



#### `pre_release` and `post_release`



#### `pre_build` and `post_build`



#### `summary`


It is also possible and probably convinient to add more `.rb` files to the `lib`
folder to allow organizing better the plugin source code.

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

### Rake Tasks

Add custom Rake tasks to your project that can be run with `ceedling <custom_task>`.
