# Ceedling’s Command Line

**Now what? How do I make it _Go_?**

Every action in Ceedling is accomplished via the command line. We'll 
cover project conventions and how to actually configure your project 
in other sections.

For now, let’s talk about the command line.

To run tests, build your release artifact, etc., you will be using the
trusty command line. Ceedling is transitioning away from being built
around Rake. As such, right now, interacting with Ceedling at the 
command line involves two different conventions:

1. **Application Commands.** Application commands tell Ceedling what to
   to do with your project. These create projects, load project files, 
   begin builds, output version information, etc. These include rich 
   help and operate similarly to popular command line tools like `git`.
1. **Build & Plugin Tasks.** Build tasks actually execute test suites, 
   run release builds, etc. These tasks are created from your project 
   file. These are generated through Ceedling’s Rake-based code and 
   conform to its conventions — simplistic help, no option flags, but 
   bracketed arguments.

In the case of running builds, both come into play at the command line.

The two classes of command line arguments are clearly labelled in the
summary of all commands provided by `ceedling help`.

## Quick command line example

To exercise the Ceedling command line quickly, follow these steps after 
[installing Ceedling](installation.md):

1. Open a terminal and chnage directories to a location suitable for
   an example project.
1. Execute `ceedling example temp_sensor` in your terminal. The `example`
   argument is an application command.
1. Change directories into the new _temp_sensor/_ directory.
1. Execute `ceedling test:all` in your terminal. The `test:all` is a
   build task executed by the default (and omitted) `build` application
   command.
1. Take a look at the build and test suite console output as well as 
   the _project.yml_ file in the root of the example project.

## Ceedling application commands

Ceedling provides robust command line help for application commands.
Execute `ceedling help` for a summary view of all application commands.
Execute `ceedling help <command>` for detailed help.

_NOTE:_ Because the built-in command line help is thorough, we will only 
briefly list and explain the available application commands.

* `ceedling [no arguments]`:

    Runs the default build tasks. Unless set in the project file, Ceedling 
    uses a default task of `test:all`. To override this behavior, set your 
    own default tasks in the project file (see later section). 

    ---

* `ceedling <tasks...>`:

    Runs the named tasks (e.g. `ceedling test:all`). Various option flags exist 
    to control project configuration loading, verbosity levels, logging, test 
    task filters, etc.

    See [next section](#ceedling-build-plugin-tasks) to understand the build & 
    plugin tasks this application command is able to execute. Run 
    `ceedling help build` to understand all the command line flags that work 
    with build & plugin tasks.

    ---

* `ceedling build <tasks...>`:

    `build` is an optional alias for the preceding (i.e. `ceedling test:all` 
    is equivalent to `ceedling build test:all`). The command actually executed
    is `ceedling build` under-the-hood. To maintain Ceedling’s historical
    command line convention, special rigging causes the `build` application
    command to be optional.

    ---

* `ceedling dumpconfig`:

    Process project configuration and write final result to a YAML file. 
    Various option flags exist to control project configuration loading,
    configuration manipulation, and configuration sub-section extraction.

    ---

* `ceedling environment`:

    Lists project related environment variables:

    * All environment variable names and string values added to your 
      environment from within Ceedling and through the `:environment`
      section of your configuration. This is especially helpful in 
      verifying the evaluation of any string replacement expressions in
      your `:environment` config entries.
    * All existing Ceedling-related environment variables set before you
      ran Ceedling from the command line.

    ---

* `ceedling example`:

    Extracts an example project from within Ceedling to your local 
    filesystem. The available examples are listed with 
    `ceedling examples`. Various option flags control whether the example
    contains vendored Ceedling and/or a documentation bundle.

    ---

* `ceedling examples`:

    Lists the available examples within Ceedling. To extract an example,
    use `ceedling example`.

    ---

* `ceedling help`:

    Displays summary help for all application commands and detailed help 
    for each command. `ceedling help` also loads your project 
    configuration (if available) and lists all build tasks from it. 
    Various option flags control what project configuration is loaded.

    ---

* `ceedling new`:

    Creates a new project structure. Various option flags control whether 
    the new project contains vendored Ceedling, a documentation bundle,
    and/or a starter project configuration file.

    ---

* `ceedling upgrade`:

    Upgrade vendored installation of Ceedling for an existing project 
    along with any locally installed documentation bundles.

    ---

* `ceedling version`:

    Displays version information for Ceedling and its components. Version output for Ceedling includes the Git Commit short SHA in Ceedling’s build identifier and Ceedling’s path of origin.
    
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
    
    If the short SHA information is unavailable such as in local development, the SHA is omitted. The source for this string is generated and captured in the Gem at the time of Ceedling’s automated build in CI.

## Ceedling build & plugin tasks

Build task are loaded from your project configuration. Unlike 
application commands that are fixed, build tasks vary depending on your
project configuration and the files within your project structure.

Ultimately, build & plugin tasks are executed by the `build` application
command (but the `build` keyword can be omitted — see above).

* `ceedling paths:*`:

    List all paths collected from `:paths` entries in your YAML config
    file where `*` is the name of any section contained in `:paths`. This
    task is helpful in verifying the expansion of path wildcards / globs
    specified in the `:paths` section of your config file.

    ---

* `ceedling files:assembly`
* `ceedling files:header`
* `ceedling files:source`
* `ceedling files:support`
* `ceedling files:test`

    List all files and file counts collected from the relevant search
    paths specified by the `:paths` entries of your YAML config file. The
    `files:assembly` task will only be available if assembly support is
    enabled in the `:release_build` or `:test_build` sections of your 
    configuration file.

    ---

* `ceedling test:all`:

    Run all unit tests.

    ---

* `ceedling test:build_only`:

    Build the entire test suite but do not execute it. This is a simple 
    validation of code and configuration via your toolchain.

    ---

* `ceedling test:*`:

    Execute the named test file or the named source file that has an
    accompanying test. No path. Examples: `ceedling test:foo`, `ceedling 
    test:foo.c` or `ceedling test:test_foo.c`

    ---

* `ceedling test:* --test-case=<test_case_name> `
    Execute individual test cases which match `test_case_name`.

    For instance, if you have a test file _test_gpio.c_ containing the following 
    test cases (test cases are simply `void test_name(void)`):

    - `test_gpio_start`
    - `test_gpio_configure_proper`
    - `test_gpio_configure_fail_pin_not_allowed`

    … and you want to run only `configure` tests, you can call:

      `ceedling test:gpio --test-case=configure`

    **Test case matching notes**

    * Test case matching is on sub-strings. `--test_case=configure` matches on
      the test cases including the word _configure_, naturally. 
      `--test-case=gpio` would match all three test cases.

    ---

* `ceedling test:* --exclude_test_case=<test_case_name> `
    Execute test cases which do not match `test_case_name`.

    For instance, if you have file _test_gpio.c_ with 3 tests:

    - `test_gpio_start`
    - `test_gpio_configure_proper`
    - `test_gpio_configure_fail_pin_not_allowed`

    … and you want to run only `start` tests, you can call:

      `ceedling test:gpio --exclude_test_case=configure`

    **Test case exclusion matching notes**

    * Exclude matching follows the same sub-string logic as discussed in the
      preceding section.

    ---

* `ceedling test:pattern[*]`:

    Execute any tests whose name and/or path match the regular expression
    pattern (case sensitive). Example: `ceedling "test:pattern[(I|i)nit]"` 
    will execute all tests named for initialization testing.

    _NOTE:_ Quotes are likely necessary around the regex characters or 
    entire task to distinguish characters from shell command line operators.

    ---

* `ceedling test:path[*]`:

    Execute any tests whose path contains the given string (case
    sensitive). Example: `ceedling test:path[foo/bar]` will execute all tests
    whose path contains foo/bar. _Notes:_

    1. Both directory separator characters `/` and `\` are valid.
    1. Quotes may be necessary around the task to distinguish the parameter’s
      characters from shell command line operators.

    ---

* `ceedling release`:

    Build all source into a release artifact (if the release build option
    is configured).

    ---

* `ceedling release:compile:*`:

    Sometimes you just need to compile a single file dagnabit. Example:
    `ceedling release:compile:foo.c`

    ---

* `ceedling release:assemble:*`:

    Sometimes you just need to assemble a single file doggonit. Example:
    `ceedling release:assemble:foo.s`

    ---

* `ceedling summary`:

    If plugins are enabled, this task will execute the summary method of
    any plugins supporting it. This task is intended to provide a quick
    roundup of build artifact metrics without re-running any part of the
    build.

    ---

* `ceedling clean`:

    Deletes all toolchain binary artifacts (object files, executables),
    test results, and any temporary files. Clean produces no output at the
    command line unless verbosity has been set to an appreciable level.

    ---

* `ceedling clobber`:

    Extends clean task’s behavior to also remove generated files: test
    runners, mocks, preprocessor output. Clobber produces no output at the
    command line unless verbosity has been set to an appreciable level.

## Command line extra credit

### Combining tasks

Multiple build tasks can be executed at the command line.

For example, `ceedling clobber test:all release` will remove all generated
files; build and run all tests; and then build all source — in that order. If
any task fails along the way, execution halts before the next task.

Task order is executed as provided and can be important! Running `clobber` after
a `test:` or `release:` task will not accomplish much.

### Builds & Revision Control

The `clobber` task removes certain build directories in the course of 
deleting generated files.

In general, it’s best not to add to source control any Ceedling generated 
directories below the root of your top-level project build directory. That is, 
leave anything Ceedling & its accompanying tools generate out of source control.

<br/><br/>
