# `:tools` Configuring command line tools used for build steps

Ceedling requires a variety of tools to work its magic. By default, the GNU
toolchain (`gcc`, `cpp`, `as` — and `gcov` via plugin) are configured and ready
for use with no additions to your project configuration YAML file.

A few items before we dive in:

1. Sometimes Ceedling's built-in tools are _nearly_ what you need but not
   quite. If you only need to add some arguments to all uses of tool's command
   line, Ceedling offers a shortcut to do so. See the
   [final section of the `:tools`][tool-definition-shortcuts] documentation for
   details.
1. If you need fine-grained control of the arguments Ceedling uses in the build
   steps for test executables, see the documentation for [`:flags`][flags].
   Ceedling allows you to control the command line arguments for each test
   executable build — with a variety of pattern matching options.
1. If you need to link libraries — your own or standard options — please see the
   [top-level `:libraries` section][libraries] available for your configuration
   file. Ceedling supports a number of useful options for working with
   pre-compiled libraries. If your library linking needs are super simple, the
   shortcut in (1) might be the simplest option.

[flags]: flags.md
[tool-definition-shortcuts]: #ceedling-tool-modification-shortcuts
[libraries]: libraries.md

## Ceedling tools for test suite builds

Our recommended approach to writing and executing test suites relies on the GNU
toolchain. _*Yes, even for embedded system work on platforms with their own,
proprietary C toolchain.*_ Please see
[this section of documentation][sweet-suite] to understand this recommendation
among all your options.

You can and sometimes must run a Ceedling test suite in an emulator or on
target, and Ceedling allows you to do this through tool definitions documented
here. Generally, you'll likely want to rely on the default definitions.

[sweet-suite]: ../../overview.md#all-your-sweet-sweet-test-suite-options

## Ceedling tools for release builds

More often than not, release builds require custom tool definitions. The GNU
toolchain is configured for Ceedling release builds by default just as with test
builds. You'll likely need your own definitions for `:release_compiler`,
`:release_linker`, and possibly `:release_assembler`.

## Ceedling plugin tools

Ceedling plugins are free to define their own tools that are loaded into your
project configuration at startup. Plugin tools are defined using the same
mechanisms as Ceedling's built-in tools and are called the same way. That is,
all features available to you for working with tools as an end user are
generally available for working with plugin-based tools. This presumes a plugin
author followed guidance and convention in creating any command line actions.

## Ceedling tool definitions

Contained in this section are details on Ceedling's default tool definitions.
For sake of space, the entirety of a given definition is not shown. If you need
to get in the weeds or want a full example, see the file `defaults.rb` in
Ceedling's lib/ directory.

### Tool definition overview

Listed below are the built-in tool names, corresponding to build steps along
with the numbered parameters that Ceedling uses to fill out a full command line
for the named tool. The full list of fundamental elements for a tool definition
are documented in the sections that follow along with examples.

Not every numbered parameter listed immediately below must be referenced in a
Ceedling tool definition. If `${4}` isn't referenced by your custom tool,
Ceedling simply skips it while expanding a tool definition into a command line.

The numbered parameters below are references that expand / are replaced with
actual values when the corresponding command line is constructed. If the values
behind these parameters are lists, Ceedling expands the containing reference
multiple times with the contents of the value. A conceptual example is
instructive…

### Simplified tool definition / expansion example

A partial tool definition:

```yaml
:tools:
   :power_drill:
      :executable: dewalt.exe
      :arguments:
         - "--X${3}"
```

Let's say that `${3}` is a list inside Ceedling, `[2, 3, 7]`. The expanded tool
command line for `:tools` ↳ `:power_drill` would look like this:

```shell
 > dewalt.exe --X2 --X3 --X7
```

## Ceedling's default build step tool definitions

**_NOTE:_** Ceedling's tool definitions for its preprocessing and backtrace
features are not documented here. Ceedling's use of tools for these features are
tightly coupled to the options and output of those tools. Drop-in replacements
using other tools are not practically possible. Eventually, an improved plugin
system will provide options for integrating alternative tools.

## `:test_compiler`

Compiler for test & source-under-test code

 - `${1}`: Input source
 - `${2}`: Output object
 - `${3}`: Optional output list
 - `${4}`: Optional output dependencies file
 - `${5}`: Header file search paths
 - `${6}`: Command line #defines

**Default**: `gcc`

## `:test_assembler`

Assembler for test assembly code

 - `${1}`: input assembly source file
 - `${2}`: output object file
 - `${3}`: search paths
 - `${4}`: #define symbols (accepted but ignored by GNU assembler)

**Default**: `as`

## `:test_linker`

Linker to generate test fixture executables

 - `${1}`: input objects
 - `${2}`: output binary
 - `${3}`: optional output map
 - `${4}`: optional library list
 - `${5}`: optional library path list

**Default**: `gcc`

## `:test_fixture`

Executable test fixture

 - `${1}`: simulator as executable with `${1}` as input binary file argument or native test executable

**Default**: `${1}`

## `:release_compiler`

Compiler for release source code

 - `${1}`: input source
 - `${2}`: output object
 - `${3}`: optional output list
 - `${4}`: optional output dependencies file

**Default**: `gcc`

## `:release_assembler`

Assembler for release assembly code

 - `${1}`: input assembly source file
 - `${2}`: output object file
 - `${3}`: search paths
 - `${4}`: #define symbols (accepted but ignored by GNU assembler)

**Default**: `as`

## `:release_linker`

Linker for release source code

 - `${1}`: input objects
 - `${2}`: output binary
 - `${3}`: optional output map
 - `${4}`: optional library list
 - `${5}`: optional library path list

**Default**: `gcc`

### Tool definition configurable elements

1. `:executable` - Command line executable (required).

    NOTE: If an executable contains a space (e.g. `Code Cruncher`), and the
    shell executing the command line generated from the tool definition needs
    the name quoted, add escaped quotes in the YAML:

    ```yaml
    :tools:
      :test_compiler:
        :executable: \"Code Cruncher\"
    ```

1. `:arguments` - List (array of strings) of command line arguments and
    substitutions (required).

1. `:name` - Simple name (i.e. "nickname") of tool beyond its executable name.
   This is optional. If not explicitly set then Ceedling will form a name from
   the tool's YAML entry key.

1. `:stderr_redirect` - Control of capturing `$stderr` messages
   {`:none`, `:auto`, `:win`, `:unix`, `:tcsh`}.
   Defaults to `:none` if unspecified. You may create a custom entry by
   specifying a simple string instead of any of the recognized symbols. As an
   example, the `:unix` symbol maps to the string `2>&1` that is automatically
   inserted at the end of a command line.

   This option is rarely necessary. `$stderr` redirection was originally often
   needed in early versions of Ceedling. Shell output stream handling is now
   automatically handled. This option is preserved for possible edge cases.

1. `:optional` - By default a tool you define is required for operation. This
   means a build will be aborted if Ceedling cannot find your tool's executable
   in your environment. However, setting `:optional` to `true` causes this
   check to be skipped. This is most often needed in plugin scenarios where a
   tool is only needed if an accompanying configuration option requires it. In
   such cases, a programmatic option available in plugin Ruby code using the
   Ceedling class `ToolValidator` exists to process tool definitions as needed.

### Tool element runtime substitution

To accomplish useful work on multiple files, a configured tool will most often
require that some number of its arguments or even the executable itself change
for each run. Consequently, every tool's argument list and executable field
possess two means for substitution at runtime.

Ceedling provides inline Ruby string expansion and a notation for populating
tool elements with dynamically gathered values within the build environment.

#### Tool element runtime substitution: Inline Ruby string expansion

`"#{...}"`: This notation is that of the beloved
[inline Ruby string expansion][inline-ruby-string-expansion] available in a
variety of configuration file sections. This string expansion occurs each time
a tool configuration is executed during a build.

#### Tool element runtime substitution: Notational substitution

A Ceedling tool's other form of dynamic substitution relies on a `$` notation.
These `$` operators can exist anywhere in a string and can be decorated in any
way needed. To use a literal `$`, escape it as `\\$`.

* `$`: Simple substitution for value(s) globally available within the runtime
  (most often a string or an array).

* `${#}`: When a Ceedling tool's command line is expanded from its configured
  representation, runs of that tool will be made with a parameter list of
  substitution values. Each numbered substitution corresponds to a position in
  a parameter list.

   * In the case of a compiler `${1}` will be a C code file path, and `${2}`
     will be the file path of the resulting object file.

   * For a linker `${1}` will be an array of object files to link, and `${2}`
     will be the resulting binary executable.

   * For an executable test fixture `${1}` is either the binary executable
     itself (when using a local toolchain such as GCC) or a binary input file
     given to a simulator in its arguments.

## Example `:tools` YAML blurb

```yaml
:tools:
  :test_compiler:
     :executable: compiler              # Exists in system search path
     :name: 'acme test compiler'
     :arguments:
        - -I"${5}"                      # Expands to -I search paths from `:paths` section + build directive path macros
        - -D"${6}"                      # Expands to all -D defined symbols from `:defines` section
        - --network-license             # Simple command line argument
        - -optimize-level 4             # Simple command line argument
        - "#{`args.exe -m acme.prj`}"   # In-line Ruby call to shell out & build string of arguments
        - -c ${1}                       # Source code input file
        - -o ${2}                       # Object file output
  
  :test_linker:
     :executable: /programs/acme/bin/linker.exe  # Full file path
     :name: 'acme test linker'
     :arguments:
        - ${1}               # List of object files to link
        - -l$-lib:           # In-line YAML array substitution to link in foo-lib and bar-lib
           - foo
           - bar
        - -o ${2}            # Binary output artifact
  
  :test_fixture:
     :executable: tools/bin/acme_simulator.exe  # Relative file path to command line simulator
     :name: 'acme test fixture'
     :stderr_redirect: :win                     # Inform Ceedling what model of $stderr capture to use
     :arguments:
        - -mem large         # Simple command line argument
        - -f "${1}"          # Binary executable input file for simulator
```

### `:tools` example blurb notes

* `${#}` is a replacement operator expanded by Ceedling with various strings,
  lists, etc. assembled internally. The meaning of each number is specific to
  each predefined default tool (see documentation above).

* See [search path order][##-search-path-order] to understand how the
  `-I"${5}"` term is expanded.

* At present, `$stderr` redirection is primarily used to capture errors from
  test fixtures so that they can be displayed at the conclusion of a test run.
  For instance, if a simulator detects a memory access violation or a divide by
  zero error, this notice might go unseen in all the output scrolling past in a
  terminal.

* The built-in preprocessing tools _can_ be overridden with non-GCC
  equivalents. However, this is highly impractical to do as preprocessing
  features are quite dependent on the idiosyncrasies and features of the GCC
  toolchain.

### Example Test Compiler Tooling

Resulting compiler command line construction from preceding example `:tools`
YAML blurb…

```shell
> compiler -I"/usr/include" -I"project/tests"
  -I"project/tests/support" -I"project/source" -I"project/include"
  -DTEST -DLONG_NAMES -network-license -optimize-level 4 arg-foo
  arg-bar arg-baz -c project/source/source.c -o
  build/tests/out/source.o
```

Notes on compiler tooling example:

- `arg-foo arg-bar arg-baz` is a fabricated example string collected from
  `$stdout` as a result of shell execution of `args.exe`.
- The `-c` and `-o` arguments are fabricated examples simulating a single
  compilation step for a test; `${1}` & `${2}` are single files.

### Example Test Linker Tooling

Resulting linker command line construction from preceding example `:tools`
YAML blurb…

```shell
> \programs\acme\bin\linker.exe thing.o unity.o
  test_thing_runner.o test_thing.o mock_foo.o mock_bar.o -lfoo-lib
  -lbar-lib -o build\tests\out\test_thing.exe
```

Notes on linker tooling example:

- In this scenario `${1}` is an array of all the object files needed to link a
  test fixture executable.

### Example Test Fixture Tooling

Resulting test fixture command line construction from preceding example `:tools`
YAML blurb…

```shell
> tools\bin\acme_simulator.exe -mem large -f "build\tests\out\test_thing.bin 2>&1"
```

Notes on test fixture tooling example:

1. `:executable` could have simply been `${1}` if we were compiling and running
   native executables instead of cross compiling. That is, if the output of the
   linker runs on the host system, then the test fixture _is_ `${1}`.
1. We're using `$stderr` redirection to allow us to capture simulator error
   messages to `$stdout` for display at the run's conclusion.

## Ceedling tool modification shortcuts

Sometimes Ceedling's default tool definitions are _this close_ to being just
what you need. But, darn, you need one extra argument on the command line, or
you just need to hack the tool executable. You'd love to get away without
overriding an entire tool definition just in order to tweak it.

We got you.

### Ceedling tool executable replacement

Sometimes you need to do some sneaky stuff. We get it. This feature lets you
replace the executable of a tool definition — including an internal default —
with your own.

To use this shortcut, simply add a configuration section to your project file
at the top-level, `:tools_<tool_to_modify>` ↳ `:executable`. Of course, you
can combine this with the following modification option in a single block for
the tool. Executable replacement can make use of
[inline Ruby string expansion][inline-ruby-string-expansion].

See the list of tool names at the beginning of the `:tools` documentation to
identify the named options. Plugins can also include their own tool definitions
that can be modified with this same option.

This example YAML...

```yaml
:tools_test_compiler:
   :executable: foo
```

... will produce the following:

```shell
 > foo <Ceedling default command line>
```

### Ceedling tool arguments addition shortcut

Now, this little feature only allows you to add arguments to the end of a tool
command line. Not the beginning. And, you can't remove arguments with this
option.

Further, this little feature is a blanket application across all uses of a
tool. If you need fine-grained control of command line flags in build steps per
test executable, please see the [`:flags` configuration documentation][flags].

To use this shortcut, simply add a configuration section to your project file
at the top-level, `:tools_<tool_to_modify>` ↳ `:arguments`. Of course, you can
combine this with the preceding modification option in a single block for the
tool.

See the list of tool names at the beginning of the `:tools` documentation to
identify the named options. Plugins can also include their own tool definitions
that can be modified with this same hack.

This example YAML...

```yaml
:tools_test_compiler:
   :arguments:
      - --flag # Add `--flag` to the end of all test C file compilation
```

... will produce the following (for the default executable):

```shell
 > gcc <Ceedling default command line> --flag
```

[inline-ruby-string-expansion]: ../project-file.md#inline-ruby-string-expansion
