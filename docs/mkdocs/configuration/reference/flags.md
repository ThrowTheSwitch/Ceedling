# `:flags` Configure preprocessing, compilation & linking command line flags

Ceedling's internal, default tool configurations execute compilation and linking
of test and source files among a variety of other tooling needs. (See later
`:tools` section.)

These default tool configurations are a one-size-fits-all approach. If you need
to add flags to the command line for individual tests or a release build, the
`:flags` section allows you to easily do so.

Entries in `:flags` modify the command lines for tools used at build time.

## Flags organization: Contexts, Operations, and Matchers

The basic layout of `:flags` involves the concepts of contexts and operations.

General case:
```yaml
:flags:
  :<context>:      # :test or :release
    :<operation>:  # :preprocess, :compile, :assemble, or :link
      - <flag>
      - ...
```

Advanced matching for **_test_** build handling only:
```yaml
:flags:
  :test:
    :<operation>:  # :preprocess, :compile, :assemble, or :link
      :<matcher>:  # Matches a subset of test executables 
        - <flag>   # List of flags added to that subset's build operation command line
        - ...
```

A context is the build context you want to modify — `:test` or `:release`.
Plugins can also hook into `:flags` with their own context.

An operation is the build step you wish to modify — `:preprocess`, `:compile`,
`:assemble`, or `:link`.

* The `:preprocess` operation is only used from within the `:test` context.
* The `:assemble` operation is only of use within the `:test` or `:release`
  contexts if assembly support has been enabled in `:test_build` or
  `:release_build`, respectively, and assembly files are a part of the project.

You specify the flags you want to add to a build step beneath `:<context>` ↳
`:<operation>`. In many cases this is a simple YAML list of strings that will
become flags in a tool's command line.

**_Specifically and only in the `:test` context_** you also have the option to
create test file matchers that apply flags to some subset of your test build.
Note that file matchers and the simpler flags list format cannot be mixed for
`:flags` ↳ `:test`.

## `:flags` ↳ `:release` ↳ `:compile`

This project configuration entry adds the items of a simple YAML list as flags
to compilation of every C file in a release build.

**Default**: `[]` (empty)

## `:flags` ↳ `:release` ↳ `:link`

This project configuration entry adds the items of a simple YAML list as flags
to the link step of a release build artifact.

**Default**: `[]` (empty)

## `:flags` ↳ `:test` ↳ `:compile`

This project configuration entry adds the specified items as flags to
compilation of C components in a test executable's build.

Flags may be represented in a simple YAML list or with a more sophisticated
file matcher YAML key plus flag list. Both are documented below.

**Default**: `[]` (empty)

## `:flags` ↳ `:test` ↳ `:preprocess`

This project configuration entry adds the specified items as flags to any
needed preprocessing of components in a test executable's build. Preprocessing
must be enabled for this matching to have any effect. (See `:project` ↳
`:use_test_preprocessor`.)

Preprocessing here refers to handling macros, conditional includes, etc. in
header files that are mocked and in complex test files before runners are
generated from them. (See more about the
[Ceedling preprocessing](../../testing-guide/conventions.md#ceedling-preprocessing-behavior-for-your-tests)
feature.)

Flags may be represented in a simple YAML list or with a more sophisticated
file matcher YAML key plus flag list. Both are documented below.

_NOTE:_ Left unspecified, `:preprocess` flags default to behaving identically
to `:compile` flags. Override this behavior by adding `:test` ↳ `:preprocess`
flags. If you want no additional flags for preprocessing regardless of test
compilation flags, simply specify an empty list `[]`.

**Default**: Same flags as specified for test compilation

## `:flags` ↳ `:test` ↳ `:link`

This project configuration entry adds the specified items as flags to the link
step of test executables.

Flags may be represented in a simple YAML list or with a more sophisticated
file matcher YAML key plus flag list. Both are documented below.

**Default**: `[]` (empty)

## `:flags` ↳ `:<plugin context>`

Some advanced plugins make use of build contexts as well. For instance, the
Ceedling Gcov plugin uses a context of `:gcov`, surprisingly enough. For any
plugins with tools that take advantage of Ceedling's internal mechanisms, you
can add to those tools' flags in the same manner as the built-in contexts and
operations.

## Simple `:flags` configuration

A simple and common need is enforcing a particular C standard. The following
example illustrates simple YAML lists for flags.

```yaml
:flags:
  :release:
    :compile:
      - -std=c99  # Add `-std=c99` to compilation of all C files in the release build
  :test:
    :compile:
      - -std=c99  # Add `-std=c99` to the compilation of all C files in all test executables
```

Given the YAML blurb above, when test or release compilation occurs, the flag
specifying the C standard will be in the command line for compilation of all C
files.

## Advanced `:flags` per-test matchers

Ceedling treats each test executable as a mini project. As a reminder, each
test file, together with all C sources and frameworks, becomes an individual
test executable of the same name.

_In the `:test` context only_, flags can be applied to build step operations —
preprocessing, compilation, and linking — for only those test executables that
match file name criteria. Matchers match on test filenames only, and the
specified flags are added to the build step for all files that are components
of matched test executables.

In short, for instance, this means your compilation of _TestA_ can have
different flags than compilation of _TestB_. And, in fact, those flags will be
applied to every C file that is compiled as part those individual test
executable builds.

### `:flags` per-test matcher examples with YAML

Before detailing matcher capabilities and limits, here are examples to
illustrate the basic ideas of test file name matching.

```yaml
:flags:
  :test:
    :compile:
      :*:              #  Wildcard: Add '-foo' for all files compiled for all test executables
        - -foo         
      :Model:          # Substring: Add '-Wall' for all files compiled for any test executable with 'Model' in its filename
        - -Wall
      :/M(ain|odel)/:  #     Regex: Add 🏴‍☠️ flag for all files compiled for any test executable with 'Main' or 'Model' in its filename
        - -🏴‍☠️
      :Comms*Model:
        - --freak      #  Wildcard: Add your `--freak` flag for all files compiled for any test executable with zero or more
                       #            characters between 'Comms' and 'Model'
    :link:
      :tests/comm/TestUsart.c:  # Substring: Add '--bar --baz' to the link step of the TestUsart executable
        - --bar
        - --baz
```

### Using `:flags` per-test matchers

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
* Wildcard matching is effectively a simplified form of regex. That is, 
  multiple approaches to matching can match the same filename.

Flags by matcher are cumulative. This means the flags from multiple matchers
can be applied to all files processed by the named build operation for any
single test executable.

Referencing the example above, here are the extra compilation flags for a
handful of test executables:

* _test_Something_: `-foo`
* _test_Main_: `-foo -🏴‍☠️`
* _test_Model_: `-foo -Wall -🏴‍☠️`
* _test_CommsSerialModel_: `-foo -Wall -🏴‍☠️ --freak`

The simple `:flags` list format remains available for the `:test` context. Of
course, this format is limited in that it applies flags to all C files processed
by the named build operation for all test executables.

This simple list format for the `:test` context…

```yaml
:flags:
  :test:
    :compile:
      - -foo
```

…is equivalent to this matcher version:

```yaml
:flags:
  :test:
    :compile:
      :*:
        - -foo
```

### Distinguishing similar or identical filenames with `:flags` per-test matchers

You may find yourself needing to distinguish test files with the same name or
test files with names whose base naming is identical.

Of course, identical test filenames have a natural distinguishing feature in
their containing directory paths. Files of the same name can only exist in
different directories. As such, your matching must include the path.

```yaml
:flags:
  :test:
    :compile:
      :hardware/test_startup:  # Match any test names beginning with 'test_startup' in hardware/ directory
        - A                  
      :network/test_startup:   # Match any test names beginning with 'test_startup' in network/ directory
        - B
```

It's common in C file naming to use the same base name for multiple files.
Given the following example list, care must be given to matcher construction to
single out test_comm_startup.c.

* tests/test_comm_hw.c
* tests/test_comm_startup.c
* tests/test_comm_startup_timers.c

```yaml
:flags:
  :test:
    :compile:
      :test_comm_startup.c: # Full filename with extension distinguishes this file test_comm_startup_timers.c
        - FOO
```

The preceding examples use substring matching, but, regular expression matching
could also be appropriate.

### Using YAML anchors & aliases for complex testing scenarios with `:flags`

See the short but helpful article on [YAML anchors & aliases][yaml-anchors-aliases]
to understand these features of YAML.

Particularly in testing complex projects, per-test file matching may only get
you so far in meeting your build step flag needs. For instance, you may need to
set various flags for operations across many test files, but no convenient name
matching scheme works. Advanced YAML features can help you copy the same flags
into multiple `:flags` test file matchers.

Please see the discussion in [`:defines`][defines] for a complete example.

[yaml-anchors-aliases]: https://support.atlassian.com/bitbucket-cloud/docs/yaml-anchors/
[defines]: defines.md
