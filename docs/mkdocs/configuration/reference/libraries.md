# `:libraries`

**Pull in specific libraries for release and test builds**

## `:libraries` example YAML

```yaml
:paths:
  :libraries:
    - proj/libs     # Linker library search paths

:libraries:
  :test:
    - test/commsstub.lib  # Imagined communication library that logs to console without traffic
  :release:
    - release/comms.lib   # Imagined production communication library
  :system:
    - math          # Add system math library to test & release builds 
  :flag: -Lib=${1}  # This linker does not follow the gcc convention
```

## `:libraries` ↳ `:test`

Libraries that should be injected into your test builds when linking occurs.

These can be specified as naked library names or with relative paths if search
paths are specified with `:paths` ↳ `:libraries`. Otherwise, absolute paths
may be used here.

These library files **must** exist when tests build.

**Default**: `[]` (empty)

## `:libraries` ↳ `:release`

Libraries that should be injected into your release build when linking occurs.

These can be specified as naked library names or with relative paths if search
paths are specified with `:paths` ↳ `:libraries`. Otherwise, absolute paths
may be used here.

These library files **must** exist when the release build occurs **unless** you
are using the _subprojects_ plugin. In that case, the plugin will attempt to
build the needed library for you as a dependency.

**Default**: `[]` (empty)

## `:libraries` ↳ `:system`

Libraries listed here will be injected into releases and tests.

These libraries are assumed to be findable by the configured linker tool, should
need no path help, and can be specified by common linker shorthand for libraries.

For example, specifying `m` will include the math library per the GCC
convention. The file itself on a Unix-like system will be `libm` and the `gcc`
command line argument will be `-lm`.

**Default**: `[]` (empty)

## `:flag`

Command line argument format for specifying a library.

**Default**: `-l${1}` (GCC format)

## `:path_flag`

Command line argument format for adding a library search path.

Library search paths may be added to your project with `:paths` ↳ `:libraries`.

**Default**: `-L "${1}"` (GCC format)

## `:libraries` notes

* If you've specified your own link step, you are going to want to add `${4}` to
  your argument list in the position where library files should be added to the
  command line. For `gcc`, this is often at the very end. Other tools may vary.
  See the `:tools` section for more.
