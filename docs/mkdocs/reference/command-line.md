# Command Line Reference

For a conceptual overview of how application commands and build & plugin 
tasks work together along with quick-start examples, see
[_Getting started: The command line_](../getting-started/command-line.md).

!!! note "Documentation convention"
    The `*` used in this reference is a stand-in for:

    * One of several available options
    * A matching string (e.g. test filename)
    * A regex

## Application commands

!!! tip "Detailed command line help at the, well, command line"
    Ceedling provides robust help for application commands.
    Execute `ceedling help` for a summary view of all application commands.
    Execute `ceedling help <command>` for detailed help.

    Because the built-in command line help is thorough, the following 
    reference includes brief entries.

---

### `ceedling [no arguments]`

Runs the default build tasks. Unless set in the project file, Ceedling 
uses a default task of `test:all`. To override this behavior, set your 
own default tasks in the project file (see later section). 

---

### `ceedling <tasks...>`

Runs the named build tasks (i.e. `ceedling test:all`). Various option flags
exist to control project configuration loading, verbosity levels, 
logging, test task filters, etc.

See [next section](#build-plugin-tasks) to understand the build & plugin 
tasks this application command is able to execute. Run `ceedling help build` 
to understand all the command line flags that work with build & plugin tasks.

---

### `ceedling build <tasks...>`

`ceedling build` is a verbose alias for the preceding. `build` is optional 
(i.e. `ceedling test:all` is equivalent to `ceedling build test:all`).

---

### `ceedling check`

Process project configuration for validity and to check for any warnings
or automated overrides. No builds occur. Various option flags exist to 
control project configuration loading and configuration manipulation.

---

### `ceedling dumpconfig`

Process project configuration and write final result to a YAML file. 
Various option flags exist to control project configuration loading,
configuration manipulation, and configuration sub-section extraction.

---

### `ceedling environment`

Lists project related environment variables:

* All environment variable names and string values added to your 
  environment from within Ceedling and through the `environment`
  section of your configuration. This is especially helpful in 
  verifying the evaluation of any string replacement expressions in
  your `environment` config entries.
* All existing Ceedling-related environment variables set before you
  ran Ceedling from the command line.

---

### `ceedling example`

Extracts an example project from within Ceedling to your local 
filesystem. The available examples are listed with 
`ceedling examples`. Various option flags control whether the example
contains vendored Ceedling and/or a documentation bundle.

---

### `ceedling examples`

Lists the available examples within Ceedling. To extract an example,
use `ceedling example`.

---

### `ceedling help`

  Displays summary help for all application commands and detailed help 
  for each command. `ceedling help` also loads your project 
  configuration (if available) and lists all build tasks from it. 
  Various option flags control what project configuration is loaded.

---

### `ceedling new`

  Creates a new project structure. Various option flags control whether 
  the new project contains vendored Ceedling, a documentation bundle,
  and/or a starter project configuration file.

---

### `ceedling upgrade`

  Upgrade vendored installation of Ceedling for an existing project 
  along with any locally installed documentation bundles.

---

### `ceedling version`

Displays version information for Ceedling and its components. Version 
output for Ceedling includes the Git Commit short SHA in Ceedling’s 
build identifier and Ceedling’s path of origin.

```
🌱 Welcome to Ceedling!

  Ceedling => #.#.#-<Short SHA>
  ----------------------
  <Ceedling install path>

  Build Frameworks
  ----------------------
      CMock => #.#.#
      Unity => #.#.#
  CException => #.#.#
```

If the short SHA information is unavailable such as in local 
development, the SHA is omitted. The source for this string is 
generated and captured in the Ruby Gem at the time of Ceedling’s 
automated build in CI.

## Build & plugin tasks

Build task are loaded from your project configuration. Unlike 
application commands that are fixed, build tasks vary depending on your
project configuration and the files within your project structure.

Ultimately, build & plugin tasks are executed by the
[`build` application command](#ceedling-build-tasks)
(but the `build` keyword can be omitted — see above).

!!! warning "Quotes in shell command line parsing"
    Quotes may be necessary around any tasks using bracket notation or that
    can make use of wildcards or regexes. Your shell will likely need quotes
    to distinguish the parameter’s characters from shell command line
    operators.

---

### `ceedling paths:*`

List all paths collected from `paths` entries in your YAML config
file where `*` is the name of any section contained in `paths`. This
task is helpful in verifying the expansion of path wildcards / globs
specified in the `paths` section of your config file.

---

### `ceedling files:*`
* `ceedling files:assembly`
* `ceedling files:header`
* `ceedling files:source`
* `ceedling files:support`
* `ceedling files:test`

List all files and file counts collected from the relevant search
paths specified by the `paths` entries of your YAML config file.

The `files:assembly` task will only be available if assembly support 
is enabled in the [`:release_build`](../configuration/reference/release-build.md) 
or [`:test_build`](../configuration/reference/test-build.md)
sections of your configuration file.

---

### `ceedling test:all`

Run all unit tests.

---

### `ceedling test:*`

Execute the named test file or the named source file that has an
accompanying test. No path. Examples: `ceedling test:foo`, `ceedling 
test:foo.c` or `ceedling test:test_foo.c`

#### `ceedling test:* --test-case=<test_case_name> `
Execute individual test cases which match `test_case_name`.

For instance, if you have a test file _test_gpio.c_ containing the following 
test cases (test cases are simply `void test_name(void)`).

- `test_gpio_start`
- `test_gpio_configure_proper`
- `test_gpio_configure_fail_pin_not_allowed`

… and you want to run only _configure_ tests, you can call:

`ceedling test:gpio --test-case=configure`

!!! note
    Test case matching is on sub-strings. `--test_case=configure` matches on
    the test cases including the word _configure_, naturally. 
    `--test-case=gpio` would match all three test cases.

#### `ceedling test:* --exclude_test_case=<test_case_name> `
Execute test cases which do not match `test_case_name`.

For instance, if you have file test_gpio.c with defined 3 tests:

- `test_gpio_start`
- `test_gpio_configure_proper`
- `test_gpio_configure_fail_pin_not_allowed`

… and you want to run only start tests, you can call:

`ceedling test:gpio --exclude_test_case=configure`

!!! note
    Exclude matching follows the same sub-string logic as discussed in the
    preceding section.

---

### `ceedling test:pattern[*]`

Execute any tests whose name and/or path match the regular expression
pattern (case sensitive). Example: `ceedling "test:pattern[(I|i)nit]"` 
will execute all tests named for initialization testing.

---

### `ceedling test:path[*]`

Execute any tests whose path contains the given string (case
sensitive). Example: `ceedling test:path[foo/bar]` will execute all tests
whose path contains foo/bar.

Both directory separator characters `/` and `\` are valid.

---

### `ceedling release`

Build all source into a release artifact (if the release build option
is configured).

---

### `ceedling release:compile:*`

Sometimes you just need to compile a single file dagnabit.

Example: `ceedling release:compile:foo.c`

---

### `ceedling release:assemble:*`

Sometimes you just need to assemble a single file doggonit. Example:
`ceedling release:assemble:foo.s`

---

### `ceedling summary`

If plugins are enabled, this task will execute the summary method of
any plugins supporting it. This task is intended to provide a quick
roundup of build artifact metrics without re-running any part of the
build.

---

### `ceedling clean`

Deletes all toolchain binary artifacts (object files, executables),
test results, and any temporary files. Clean produces no output at the
command line unless verbosity has been set to an appreciable level.

---

### `ceedling clobber`

Extends clean task’s behavior to also remove generated files: test
runners, mocks, preprocessor output. Clobber produces no output at the
command line unless verbosity has been set to an appreciable level.

<br/><br/>
