# `:defines`

**Command line symbols used in compilation**

Ceedling’s internal, default compiler tool configurations (see later `:tools`
section) execute compilation of test and source C files.

These default tool configurations are a one-size-fits-all approach. If you need
to add to the command line symbols for individual tests or a release build, the
`:defines` section allows you to easily do so.

Particularly in testing, symbol definitions in the compilation command line are
often needed:

1. You may wish to control aspects of your test suite. Conditional compilation
   statements can control which test cases execute in which circumstances.
   (Preprocessing must be enabled, `:project` ↳ `:use_test_preprocessor`.)

1. Testing means isolating the source code under test. This can leave certain
   symbols unset when source files are compiled in isolation. Adding symbol
   definitions in your Ceedling project file for such cases is one way to meet
   this need.

Entries in `:defines` modify the command lines for compilers used at build time.
In the default case, symbols listed beneath `:defines` become `-D<symbol>`
arguments.

## `:defines` verification (none)

Ceedling does no verification of your configured `:define` symbols.

Unity, CMock, and CException conditional compilation statements, your
toolchain’s preprocessor, and/or your toolchain’s compiler will complain
appropriately if your specified symbols are incorrect, incomplete, or
incompatible.

Ceedling _does_ validate your `:defines` block in your project configuration.

## Contexts and Matchers

The basic layout of `:defines` involves the concept of contexts.

General case:
```yaml
:defines:
  :<context>:   # :test, :release, etc.
    - <symbol>  # Simple list of symbols added to all compilation
    - ...
```

Advanced matching for **_test_** or **_preprocess_** build handling only:
```yaml
:defines:
  :test:
    :<matcher>   # Matches a subset of test executables
      - <symbol> # List of symbols added to that subset’s compilation
      - ...
  :preprocess:   # Only applicable if :project ↳ :use_test_preprocessor enabled
    :<matcher>   # Matches a subset of test executables
      - <symbol> # List of symbols added to that subset’s compilation
      - ...
```

A context is the build context you want to modify — `:release`, `:preprocess`,
or `:test`. Plugins can also hook into `:defines` with their own context.

You specify the symbols you want to add to a build step beneath a `:<context>`.
In many cases this is a simple YAML list of strings that will become symbols
defined in a compiler’s command line.

Specifically in the `:test` and `:preprocess` contexts you also have the option
to create test file matchers that create symbol definitions for some subset of
your build.

## `:defines` ↳ `:release`

This project configuration entry adds the items of a simple YAML list as
symbols to the compilation of every C file in a release build.

**Default**: `[]` (empty)

## `:defines` ↳ `:test`

This project configuration entry adds the specified items as symbols to
compilation of C components in a test executable’s build.

Symbols may be represented in a simple YAML list or with a more sophisticated
file matcher YAML key plus symbol list. Both are documented below.

Every C file that comprises a test executable build will be compiled with the
symbols configured that match the test filename itself.

**Default**: `[]` (empty)

## `:defines` ↳ `:preprocess`

This project configuration entry adds the specified items as symbols to any
needed preprocessing of components in a test executable’s build. Preprocessing
must be enabled for this matching to have any effect. (See `:project` ↳
`:use_test_preprocessor`.)

Preprocessing here refers to handling macros, conditional includes, etc. in
header files that are mocked and in complex test files before runners are
generated from them. (See more about the
[Ceedling preprocessing](../../testing-guide/conventions.md#ceedling-preprocessing-behavior-for-your-tests)
feature.)

Like the `:test` context, compilation symbols may be represented in a simple
YAML list or with a more sophisticated file matcher YAML key plus symbol list.
Both are documented below.

!!! note "Default `:preprocess` symbols"
    Left unspecified, `:preprocess` symbols default to be identical to
    `:test` symbols. Override this behavior by adding `:defines` ↳ `:preprocess`
    symbols. If you want no additional symbols for preprocessing regardless of
    `test` symbols, specify an empty list `[]` in your `:preprocess` matcher.

**Default**: Identical to `:test` context unless specified

## `:defines` ↳ `:<plugin context>`

Some advanced plugins make use of build contexts as well. For instance, the
Ceedling Gcov plugin uses a context of `:gcov`, surprisingly enough. For any
plugins with tools that take advantage of Ceedling’s internal mechanisms, you
can add to those tools' compilation symbols in the same manner as the built-in
contexts.

## `:defines` options

* `:use_test_definition`:

  If enabled, add a symbol to test compilation derived from the test file name.
  The resulting symbol is a sanitized, uppercase, ASCII version of the test file
  name. Any non ASCII characters (e.g. Unicode) are replaced by underscores as
  are any non-alphanumeric characters. Underscores and dashes are preserved. The
  symbol name is wrapped in underscores unless they already exist in the leading
  and trailing positions. Example: _test_123abc-xyz😵.c_ ➡️ `_TEST_123ABC-XYZ_`.

  **Default**: False

## Simple `:defines` configuration

A simple and common need is configuring conditionally compiled features in a
code base. The following example illustrates using simple YAML lists for symbol
definitions at compile time.

```yaml
:defines:
  :test:     # All compilation of all C files for all test executables
    - FEATURE_X=ON
    - PRODUCT_CONFIG_C
  :release:  # All compilation of all C files in a release artifact
    - FEATURE_X=ON
    - PRODUCT_CONFIG_C
```

Given the YAML blurb above, the two symbols will be defined in the compilation
command lines for all C files in all test executables within a test suite build
and for all C files in a release build.

## Advanced `:defines` per-test matchers

Ceedling treats each test executable as a mini project. As a reminder, each
test file, together with all C sources and frameworks, becomes an individual
test executable of the same name.

**_In the `:test` and `:preprocess` contexts only_**, symbols may be defined
for only those test executable builds that match filename criteria. Matchers
match on test filenames only, and the specified symbols are added to the build
step for all files that are components of matched test executables.

In short, for instance, this means your compilation of _TestA_ can have
different symbols than compilation of _TestB_. Those symbols will be applied to
every C file that is compiled as part those individual test executable builds.
Thus, in fact, with separate test files unit testing the same source C file, you
may exercise different conditional compilations of the same source. See the
example in the section below.

### Per-test matcher examples

Before detailing matcher capabilities and limits, here are examples to
illustrate the basic ideas of test file name matching.

This first example builds on the previous simple symbol list example. The
imagined scenario is that of unit testing the same single source C file with
different product features enabled. The per-test matchers shown here use test
filename substring matchers.

```yaml
# Imagine three test files all testing aspects of a single source file Comms.c with 
# different features enabled via conditional compilation.
:defines:
  :test:
    # Tests for FeatureX configuration
    :CommsFeatureX:      # Matches a test executable name including 'CommsFeatureX'
      - FEATURE_X=ON
      - FEATURE_Z=OFF
      - PRODUCT_CONFIG_C
    # Tests for FeatureZ configuration
    :CommsFeatureZ:      # Matches a test executable name including 'CommsFeatureZ'
      - FEATURE_X=OFF
      - FEATURE_Z=ON
      - PRODUCT_CONFIG_C
    # Tests of base functionality
    :CommsBase:          # Matches a test executable name including 'CommsBase'
      - FEATURE_X=OFF
      - FEATURE_Z=OFF
      - PRODUCT_BASE
```

This example illustrates each of the test file name matcher types.

```yaml
:defines:
  :test:
    :*:              #  Wildcard: Add '-DA' for compilation all files for all test executables
      - A            
    :Model:          # Substring: Add '-DCHOO' for compilation of all files of any test executable with 'Model' in its name
      - CHOO
    :/M(ain|odel)/:  #     Regex: Add '-DBLESS_YOU' for all files of any test executable with 'Main' or 'Model' in its name
      - BLESS_YOU
    :Comms*Model:    #  Wildcard: Add '-DTHANKS' for all files of any test executables that have zero or more characters
      - THANKS       #            between 'Comms' and 'Model'
```

### Per-test matchers types

These matchers are available:

1. Wildcard (`*`) 
    1. If specified in isolation, matches all tests.
    1. If specified within a string, matches any test filename with that 
      wildcard expansion.
1. Substring — Matches on part of a test filename (up to all of it, including 
   full path).
1. Regex (`/.../`) — Matches test file names against a regular expression.

Notes:
* Substring filename matching is case sensitive.
* Wildcard matching is effectively a simplified form of regex. That is, multiple
  approaches to matching can match the same filename.

Symbols by matcher are cumulative. This means the symbols from multiple
matchers can be applied to all compilation for any single test executable.

Referencing the example above, here are the extra compilation symbols for a
handful of test executables:

* _test_Something_: `-DA`
* _test_Main_: `-DA -DBLESS_YOU`
* _test_Model_: `-DA -DCHOO -DBLESS_YOU`
* _test_CommsSerialModel_: `-DA -DCHOO -DBLESS_YOU -DTHANKS`

The simple `:defines` list format remains available for the `:test` and
`:preprocess` contexts. Of course, this format is limited in that it applies
symbols to the compilation of all C files for all test executables.

This simple list format for `:test` and `:preprocess` contexts…

```yaml
:defines:
  :test:
    - A
```

…is equivalent to this matcher version:

```yaml
:defines:
  :test:
    :*:
      - A
```

### Distinguishing similar / identical filenames

You may find yourself needing to distinguish test files with the same name or
test files with names whose base naming is identical.

Of course, identical test filenames have a natural distinguishing feature in
their containing directory paths. Files of the same name can only exist in
different directories. As such, your matching must include the path.

```yaml
:defines:
  :test:
    :hardware/test_startup:  # Match any test names beginning with 'test_startup' in hardware/ directory
      - A                  
    :network/test_startup:   # Match any test names beginning with 'test_startup' in network/ directory
      - B
```

It’s common in C file naming to use the same base name for multiple files.
Given the following example list, care must be given to matcher construction to
single out test_comm_startup.c.

* tests/test_comm_hw.c
* tests/test_comm_startup.c
* tests/test_comm_startup_timers.c

```yaml
:defines:
  :test:
    :test_comm_startup.c: # Full filename with extension distinguishes this file test_comm_startup_timers.c
      - FOO
```

The preceding examples use substring matching, but, regular expression matching
could also be appropriate.

### YAML anchors & aliases

See the short but helpful article on [YAML anchors & aliases][yaml-anchors-aliases]
to understand these features of YAML.

Particularly in testing complex projects, per-test file matching may only get
you so far in meeting your symbol definition needs. For instance, you may need
to use the same symbols across many test files, but no convenient name matching
scheme works. Advanced YAML features can help you copy the same symbols into
multiple `:defines` test file matchers.

The following advanced example illustrates how to create a set of compilation
symbols for test preprocessing that are identical to test compilation with one
addition.

In brief, this example uses YAML features to copy the `:test` matcher
configuration that matches all test executables into the `:preprocess` context
and then add an additional compilation symbol to the list.

```yaml
:defines:
  :test: &config-test-defines  # YAML anchor
    :*:  &match-all-tests      # YAML anchor
      - PRODUCT_FEATURE_X
      - ASSERT_LEVEL=2
      - USES_RTOS=1
    :test_foo:
      - DRIVER_FOO=1u
    :test_bar:
      - DRIVER_BAR=5u
  :preprocess:
    <<: *config-test-defines   # Insert all :test defines file matchers via YAML alias
    :*:                        # Override wildcard matching key in copy of *config-test-defines
      - *match-all-tests       # Copy test defines for all files via YAML alias
      - RTOS_SPECIAL_THING     # Add single additional symbol to all test executable preprocessing
                               # test_foo, test_bar, and any other matchers are present because of <<: above
```

[yaml-anchors-aliases]: https://support.atlassian.com/bitbucket-cloud/docs/yaml-anchors/

<br/><br/>
