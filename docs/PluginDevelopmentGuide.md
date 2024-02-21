# Developing Plugins for Ceedling

This guide walks you through the process of creating custom plugins for
[Ceedling](https://github.com/ThrowTheSwitch/Ceedling).

It is assumed that the reader has a working installation of Ceedling and some
basic usage experience, *i.e.* project creation/configuration and running tasks.

Some experience with Ruby and Rake will be helpful but not absolutely required.
You can learn the basics as you go — often by looking at other, existing 
Ceedling plugins or by simply searching for code examples online.

## Contents

* [Custom Plugins Overview](#custom-plugins-overview)
* [Plugin Conventions & Architecture](#plugin-conventions--architecture)
   1. [Configuration Plugin](#plugin-option-1-configuration)
   1. [Programmatic `Plugin` subclass](#plugin-option-2-plugin-subclass)
   1. [Rake Tasks Plugin](#plugin-option-3-rake-tasks)

## Development Roadmap & Notes

_February 19, 2024_

(See Ceedling's _[release notes](ReleaseNotes.md)_ for more.)

* Ceedling 0.32 marks the beginning of moving all of Ceedling away from relying
  on Rake. New, Rake-based plugins should not be developed. Rake dependencies
  among built-in plugins will be refactored as the transition occurs.
* Ceedling's entire plugin architecture will be overhauled in future releases.
  The current structure is too dependent on Rake and provides both too little
  and too much access to Ceedling's core.
* Certain aspects of Ceedling's plugin structure have developed organically.
  Consistency, coherence, and usability may not be high — particularly for 
  build step hook argument hashes and test results data structures used in 
  programmatic plugins.
* Because of iterating on Ceedling's core design and features, documentation
  here may not always be perfectly up to date.

---

# Custom Plugins Overview

Ceedling plugins extend Ceedling without modifying its core code. They are
implemented in YAML and the Ruby programming language and are loaded by 
Ceedling at runtime.

Plugins provide the ability to customize the behavior of Ceedling at various
stages of a build — preprocessing, compiling, linking, building, testing, and
reporting.

See _[CeedlingPacket]_ for basic details of operation (`:plugins` configuration
section) and for a [directory of built-in plugins][plugins-directory].

[CeedlingPacket]: CeedlingPacket.md
[plugins-directory]: CeedlingPacket.md#ceedlings-built-in-plugins-a-directory

# Plugin Conventions & Architecture

Plugins are enabled and configured from within a Ceedling project's YAML
configuration file (`:plugins` section).

Conventions & requirements:

* Plugin configuration names, the containing directory names, and filenames 
  must:
   * All match (i.e. identical names)
   * Be snake_case (lowercase with connecting underscores).
* Plugins must be organized in a containing directory (the name of the plugin
  as used in the project configuration `:plugins` ↳ `:enabled` list is its 
  containing directory name).
* A plugin's containing directory must be located in a Ruby load path. Load
  paths may be added to a Ceedling project using the `:plugins` ↳ `:load_paths`
  list.
* Rake plugins place their Rakefiles in the root of thecontaining plugin 
  directory.
* Programmatic plugins must contain either or both `config/` and `lib/`
  subdirectories within their containing directories.
* Configuration plugins must place their files within a `config/` subdirectory
  within the plugin's containing directory.

Ceedling provides 3 options to customize its behavior through a plugin. Each
strategy is implemented with source files conforming to location and naming
conventions. These approaches can be combined.

1. Configuration (YAML & Ruby)
1. `Plugin` subclass (Ruby)
1. Rake tasks (Ruby)

# Plugin Option 1: Configuration

The configuration option, surprisingly enough, provides Ceedling configuration
values. Configuration plugin values can supplement or override project
configuration values.

Not long after Ceedling plugins were developed the `option:` feature was added
to Ceedling to merge in secondary configuration files. This feature is
typically a better way to manage nultiple configurations and in many ways
supersedes a configuration plugin.

That said, a configuration plugin is more capable than the `option:` feature and
can be appropriate in some circumstances. Further, Ceedling's configuration
pluging abilities are often a great way to provide configuration to
programmatic `Plugin` subclasses (Ceedling plugins options #2).

## Three flavors of configuration plugins exist

1. **YAML defaults.** The data of a simple YAML file is incorporated into
   Ceedling's configuration defaults during startup.
1. **Programmatic (Ruby) defaults.** Ruby code creates a configuration hash 
   that Ceedling incorporates into its configuration defaults during startup. 
   This provides the greatest flexibility in creating configuration values.
1. **YAML configurations.** The data of a simple YAML file is incorporated into
   Ceedling's configuration much like Ceedling's actual configuration file.

## Example configuration plugin layout

Project configuration file:

```yaml
:plugins:
  :load_paths:
    - support/plugins
  :enabled:
    - zoom_zap
```

Ceedling project directory sturcture:

(Third flavor of configuration plugin shown.)

```
project/
├── project.yml
└── support/
    └── plugins/
        └── zoom_zap/
            └── config/
                └── zoom_zap.yml
```

## Ceedling configuration build & use

Configuration is developed at startup in this order:

1. Ceedling loads its own defaults
1. Any plugin defaults are inserted, if they do not already exist
1. Any plugin configuration is merged
1. Project file configuration is merged

Merging means that any existing configuration is replaced. If no such 
key/value pairs already exist, they are inserted into the configuration.

A plugin may further implement its own code to use custom configuration added to
the Ceedling project file. In such cases, it's typically wise to make use of a
plugin's option for defining default values. Configuration handling code is
greatly simplified if strucures and values are guaranteed to exist in some
form.

## Configuration Plugin Flavors

### Configuration Plugin Flvaor A: YAML Defaults

Naming and location convention: `<plugin_name>/config/defaults.yml`

Configuration values are defined inside a YAML file just as the Ceedling project
configuration file.

Keys and values are defined in Ceedling's “base” configuration along with all
default values Ceedling loads at startup. If a particular key/value pair is
already set at the time the plugin attempts to set it, it will not be
redefined.

YAML values are static apart from Ceedling's ability to perform string
substitution at configuration load time (see _[CeedlingPacket]_ for more).
Programmatic Ruby defaults (next section) are more flexible but more
complicated.

```yaml
# Any valid YAML is appropriate
:key:
  :value: <setting>
```

### Configuration Plugin Flvaor B: Programmatic (Ruby) Defaults

Naming and location convention: `<plugin_name>/config/defaults_<plugin_name>.rb`

Configuration values are defined in a Ruby hash returned by a “naked” function
`get_default_config()` in a Ruby file. The Ruby file is loaded and evaluated at
Ceedling startup. It can contain anything allowed in a Ruby script file but
must contain the accessor function. The returned hash's top-level keys will
live in Ceedling's configuration at the same level in the configuration
hierarchy as a Ceedling project file's top-level keys ('top-level' refers to
the left-most keys in the YAML, not to how “high” the keys are towards the top
of the file).

Keys and values are defined in Ceedling's “base” configuration along with all
default values Ceedling loads at startup. If a particular key/value pair is
already set at the time the plugin attempts to set it, it will not be
redefined.

This configuration option is more flexible than that documented in the previous
section as full Ruby execution is possible in creating the defaults hash.

### Configuration Plugin Flvaor C: YAML Values

Naming and location convention: `<plugin_name>/config/<plugin_name>.yml`

Configuration values are defined inside a YAML file just as the Ceedling project
configuration file.

Keys and values are defined in Ceedling's “base” configuration along with all
default values Ceedling loads at startup. If a particular key/value pair is
already set at the time the plugin attempts to set it, it will not be
redefined.

YAML values are static apart from Ceedling's ability to perform string
substitution at configuration load time (see _[CeedlingPacket]_ for more).
Programmatic Ruby defaults (next section) are more flexible but more
complicated.

```yaml
# Any valid YAML is appropriate
:key:
  :value: <setting>
```

# Plugin Option 2: `Plugin` Subclass

Naming and location conventions:

* `<plugin_name>/lib/<plugin_name>.rb`
* The plugin's class name must be the camelized version (a.k.a. “bumpy case")
  of the plugin filename — `whiz_bang.rb` ➡️ `WhizBang`.

This plugin option allows full programmatic ability connceted to any of a number
of predefined Ceedling build steps.

The contents of `<plugin_name>.rb` must implement a class that subclasses
`Plugin`, Ceedling's plugin base class.

## Example `Plugin` subclass

An incomplete `Plugin` subclass follows to illustate the basics.

```ruby
# whiz_bang/lib/whiz_bang.rb
require 'ceedling/plugin'

class WhizBang < Plugin
  def setup
    # ...
  end
  
  # Build step hook
  def pre_test(test)
    # ...
  end
  
  # Build step hook
  def post_test(test)
    # ...
  end
end
```

## Example programmatic plugin layout

Project configuration file:

```yaml
:plugins:
  :load_paths:
    - support/plugins
  :enabled:
    - whiz_bang
```

Ceedling project directory sturcture:

```
project/
├── project.yml
└── support/
    └── plugins/
        └── whiz_bang/
            └── lib/
                └── whiz_bang.rb
```

It is possible and often convenient to add more `.rb` files to the containing 
`lib/` directory to allow good organization of plugin code. No Ceedling 
conventions exist for these supplemental code files. Only standard Ruby 
constaints exists for these filenames and content.

## `Plugin` instance variables

Each `Plugin` sublcass has access to the following instance variables:

* `@name`
* `@ceedling`

`@name` is self explanatory. `@ceedling` is a hash containing every object 
within the Ceedling application; its keys are the filenames of the objects
minus file extension.

Objects commonly used in plugins include:

* `@ceedling[:configurator]` — Project configuration
* `@ceedling[:streaminator]` — Logging
* `@ceedling[:reportinator]` — String formatting for logging
* `@ceedling[:file_wrapper]` — File operations
* `@ceedling[:plugin_reportinator]` — Various needs including gathering test 
  results

## `Plugin` method `setup()`

If your plugin defines this method, it will be called during plugin creation at
Ceedling startup. It is effectively your constructor for your custom `Plugin`
subclass.

## `Plugin` hook methods `pre_mock_preprocess(arg_hash)` and `post_mock_preprocess(arg_hash)`

These methods are called before and after execution of preprocessing for header
files to be mocked (see [CeedlingPacket] to understand preprocessing). If a
project does not enable preprocessing or a build does not include tests, these
are not called. This pair of methods is called a number of times equal to the
number of mocks in a test build.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Filepath of header file to be preprocessed on its way to being mocked
  :header_file =>  "<filepath>",
  # Filepath of processed header file
  :preprocessed_header_file => "<filepath>",
  # Filepath of tests C file the mock will be used by
  :test => "<filepath>",
  # List of flags to be provided to `cpp` GNU preprocessor tool
  :flags => [<flags>],
  # List of search paths to be provided to `cpp` GNU preprocessor tool
  :include_paths => [<paths>],
  # List of compilation symbols to be provided to `cpp` GNU preprocessor tool
  :defines => [<defines>]
}
```

## `Plugin` hook methods `pre_test_preprocess(arg_hash)` and `post_test_preprocess(arg_hash)`

These methods are called before and after execution of test file preprocessing
(see [CeedlingPacket] to understand preprocessing). If a project does not
enable preprocessing or a build does not include tests, these are not called.
This pair of methods is called a number of times equal to the number of test
files in a test build.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Filepath of C test file to be preprocessed on its way to being used to generate runner
  :test_file => "<filepath>",
  # Filepath of processed tests file
  :preprocessed_test_file => "<filepath>",
  # Filepath of tests C file the mock will be used by
  :test => "<filepath>",
  # List of flags to be provided to `cpp` GNU preprocessor tool
  :flags => [<flags>],
  # List of search paths to be provided to `cpp` GNU preprocessor tool
  :include_paths => [<paths>],
  # List of compilation symbols to be provided to `cpp` GNU preprocessor tool
  :defines => [<defines>]
}
```

## `Plugin` hook methods `pre_mock_generate(arg_hash)` and `post_mock_generate(arg_hash)`

These methods are called before and after mock generation. If a project does not
enable mocks or a build does not include tests, these are not called. This pair
of methods is called a number of times equal to the number of mocks in a test
build.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Filepath of the header file being mocked.
  :header_file => "<filepath>",
  # Additional context passed by the calling function.
  # Ceedling passes the :test symbol by default while plugins may provide another
  :context => :<context>,
  # Filepath of the tests C file that references the requested mock
  :test => "<filepath>",
  # Filepath of the generated mock C code.
  :output_path => "<filepath>"
}
```

## `Plugin` hook methods `pre_runner_generate(arg_hash)` and `post_runner_generate(arg_hash)`

These methods are called before and after execution of test runner generation. A
test runner includes all the necessary C scaffolding (and `main()` entry point)
to call the test cases defined in a test file when a test executable runs. If a
build does not include tests, these are not called. This pair of methods is
called a number of times equal to the number of test files in a test build.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Additional context passed by the calling function.
  # Ceedling passes the :test symbol by default while plugins may provide another
  :context => :<context>,
  # Filepath of the tests C file.
  :test_file => "<filepath>",
  # Filepath of the test file to be processed (if preprocessing enabled, this is not the same as :test_file).  
  :input_file => "<filepath>",
  # Filepath of the generated tests runner file.
  :runner_file => "<filepath>"
}
```

## `Plugin` hook methods `pre_compile_execute(arg_hash)` and `post_compile_execute(arg_hash)`

These methods are called before and after source file compilation. These are
called in both test and release builds. This pair of methods is called a number
of times equal to the number of C files in a test or release build.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  :tool => {
    # Hash holding compiler tool elements (see CeedlingPacket)
  },
  # Symbol of the operation being performed, e.g. :compile, :assemble or :link
  :operation => :<operation>,
  # Additional context passed by the calling function.
  # Ceedling provides :test or :release by default while plugins may provide another.
  :context => :<context>,
  # Filepath of the input C file
  :source => "<filepath>",
  # Filepath of the output object file
  :object => "<filepath>",
  # List of flags to be provided to compiler tool
  :flags => [<flags>],
  # List of search paths to be provided to compiler tool
  :search_paths => [<paths>],
  # List of compilation symbols to be provided to compiler tool
  :defines => [<defines>],
  # Filepath of the listing file, e.g. .lst file
  :list => "<filepath>",
  # Filepath of the dependencies file, e.g. .d file
  :dependencies => "<filepath>"
}
```

## `Plugin` hook methods `pre_link_execute(arg_hash)` and `post_link_execute(arg_hash)`

These methods are called before and after linking an executable. These are
called in both test and release builds. These are called for each test
executable and each release artifact. This pair of methods is called a number
of times equal to the number of test files in a test build or release artifacts
in a release build.

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Hash holding linker tool properties.
  :tool => {
    # Hash holding compiler tool elements (see CeedlingPacket)
  },
  # Additional context passed by the calling function.
  # Ceedling provides :test or :release by default while plugins may provide another.
  :context => :<context>,
  # List of object files paths being linked, e.g. .o files
  :objects => [],
  # List of flags to be provided to linker tool
  :flags => [<flags>],
  # Filepath of the output file, e.g. .out file
  :executable => "<filepath>",
  # Filepath of the map file, e.g. .map file
  :map => "<filepath>",
  # List of libraries to link, e.g. those passed to the (GNU) linker with -l
  :libraries => [<names>],
  # List of libraries paths, e.g. the ones passed to the (GNU) linker with -L
  :libpaths => [<paths>]
}
```

## `Plugin` hook methods `pre_test_fixture_execute(arg_hash)` and `post_test_fixture_execute(arg_hash)`

These methods are called before and after running a test executable. If a build
does not include tests, these are not called. This pair of methods is called
for each test executable in a build (each test file is ultimately built into a
test executable).

The argument `arg_hash` follows the structure below:

```ruby
arg_hash = {
  # Hash holding execution tool properties.
  :tool => {
    # Hash holding compiler tool elements (see CeedlingPacket)
  },
  # Additional context passed by the calling function.
  # Ceedling provides :test or :release by default while plugins may provide another.
  :context => :<context>,
  # Name of the test file minus path and extension (`test/TestIness.c` -> 'TestIness')
  :test_name => "<name>",
  # Filepath of original tests C file that became the test executable
  :test_filepath => "<filepath>",
  # Path to the tests executable file, e.g. .out file
  :executable => "<filepath>",
  # Path to the tests result file, e.g. .pass/.fail file
  :result_file => "<filepath>"
}
```

## `Plugin` hook methods `pre_test(test)` and `post_test(test)`

These methods are called before and after performing all steps needed to run a
test file — i.e. configure, preprocess, compile, link, run, get results, etc.
This pair of methods is called for each test file in a test build.

The argument `test` corresponds to the path of the test C file being processed.

## `Plugin` hook methods `pre_release()` and `post_release()`

These methods are called before and after performing all steps needed to run the
release task — i.e. configure, preprocess, compile, link, etc.

## `Plugin` hook methods `pre_build` and `post_build`

These methods are called before and after executing any ceedling task — e.g:
test, release, coverage, etc.

## `Plugin` hook methods `post_error()`

This method is called at the conclusion of a Ceedling build that encounters any
error that halts the build process. To be clear, a test build with failing test
cases is not a build error.

## `Plugin` hook methods `summary()`

This method is called when invoking the summary task, `ceedling summary`. This
method facilitates logging the results of the last build without running the
previous build again.

## Collecting test results from within `Plugin` subclass

Some testing-specific plugins need access to test results to do their work. A
utility method is available for this purpose.

`@ceedling[:plugin_reportinator].assemble_test_results()`

This method takes as an argument a list of results filepaths. These typically
correspond directly to the collection of test files Ceedling processed in a
given test build. It's common for this list of filepaths to be assembled from
the `post_test_fixture_execute` build step execution hook.

The data that `assemble_test_results()` returns hss a structure as follows. In 
this example, actual results from a single, real test file are presented as 
hash/array Ruby code with comments and with some edits to reduce line length.

```ruby
{
  # Associates each test executable (i.e. test file) with an execution run time
  :times => {
    "test/TestUsartModel.c" => 0.21196400001645088
  },

  # List of succeeding test cases, grouped by test file.
  :successes => [
    {
      :source => {:file => "test/TestUsartModel.c", :dirname => "test", :basename => "TestUsartModel.c"},
      :collection => [
        # If Unity is configured to do so, it will output execution run time for each test case.
        # Ceedling creates a zero entry if the Unity option is not enabled.
        {:test => "testCase1", :line => 17, :message => "", :unity_test_time => 0.0},
        {:test => "testCase2", :line => 31, :message => "", :unity_test_time => 0.0}
      ]
    }
  ],

  # List of failing test cases, grouped by test file.
  :failures => [
    {
      :source => {:file => "test/TestUsartModel.c", :dirname => "test", :basename => "TestUsartModel.c"},
      :collection => [
        {:test => "testCase3", :line => 25, :message => "<failure message>", :unity_test_time => 0.0}
      ]
    }
  ],

  # List of ignored test cases, grouped by test file.
  :ignores => [
    {
      :source => {:file => "test/TestUsartModel.c", :dirname => "test", :basename => "TestUsartModel.c"},
      :collection => [
        {:test => "testCase4", :line => 39, :message => "", :unity_test_time => 0.0}
      ]
    }
  ],

  # List of strings printed to $stdout, grouped by test file.
  :stdout => [
    {
      :source => {:file => "test/TestUsartModel.c", :dirname => "test", :basename => "TestUsartModel.c"},
      # Calls to print to $stdout are outside Unity's scope, preventing attaching test file line numbers
      :collection => [
        "<$stdout string (e.g. printf() call)>"
      ]
    }
  ],

  # Test suite run stats
  :counts => {
    :total   => 4,
    :passed  => 2,
    :failed  => 1,
    :ignored => 1,
    :stdout  => 1},

  # The sum of all test file execution run times
  :total_time => 0.21196400001645088
}
```

# Plugin Option 3: Rake Tasks

This plugin type adds custom Rake tasks to your project that can be run with `ceedling <custom_task>`.

Naming and location conventions: `<plugin_name>/<plugin_name>.rake`

## Example Rake task

```ruby
# Only tasks with description are listed by `ceedling -T`
desc "Print hello world to console"
task :hello_world do
  sh "echo Hello World!"
end
```

Resulting, example command line:

```shell
 > ceedling hello_world
 > Hello World!
```

## Example Rake plugin layout

Project configuration file:

```yaml
:plugins:
  :load_paths:
    - support/plugins
  :enabled:
    - hello_world
```

Ceedling project directory sturcture:

```
project/
├── project.yml
└── support/
    └── plugins/
        └── hello_world/
            └── hello_world.rake
```