# `:cmock`

**Configure CMock’s code generation & compilation**

Ceedling sets values for a subset of CMock settings. All CMock options are
available to be set, but only those options set by Ceedling in an automated
fashion are documented below. See [CMock documentation][cmock-docs].

## `:enforce_strict_ordering`

Tests fail if expected call order is not same as source order

**Default**: TRUE

## `:verbosity`

If not set, defaults to Ceedling’s verbosity level

## `:defines`

Adds list of symbols used to configure CMock’s C code features in its source
and header files at compile time.

See [Using Unity, CMock & CException](../../testing-guide/frameworks.md) for
much more on configuring and making use of these frameworks in your build.

To manage overall command line length, these symbols are only added to
compilation when a CMock C source file is compiled.

No symbols must be set unless CMock’s defaults are inappropriate for your
environment and needs.

**Default**: `[]` (empty)

## `:plugins`

To enable CMock’s optional and advanced features available via CMock plugin,
simply add `:cmock` ↳ `:plugins` to your configuration and specify your desired
additional CMock plugins as a simple list of the plugin names.

See [CMock’s documentation][cmock-docs] to understand plugin options.

**Default**: `[]` (empty)

## `:unity_helper_path`

A Unity helper is a simple header file used by convention to support your
specialized test case needs. For example, perhaps you want a Unity assertion
macro for the contents of a struct used throughout your project. Write the macro
you need in a Unity helper header file and `#include` that header file in your
test file.

When a Unity helper is provided to CMock, it takes on more significance, and
more magic happens. CMock parses Unity helper header files and uses macros of a
certain naming convention to extend CMock’s handling of mocked parameters.

See the [Unity and CMock documentation](../../testing-guide/frameworks.md) 
for more details.

`:unity_helper_path` may be a single string or a list. Each value must be a
relative path from your Ceedling working directory to a Unity helper header file
(these are typically organized within containing Ceedling `:paths` ↳ `:support`
directories).

**Default**: `[]` (empty)

## `:includes`

In certain advanced testing scenarios, you may need to inject additional header
files into generated mocks. The filenames in this list will be transformed into
`#include` directives created at the top of every generated mock.

If `:unity_helper_path` is in use (see preceding), the filenames at the end of
any Unity helper file paths will be automatically injected into this list
provided to CMock.

**Default**: `[]` (empty)

## Notes on Ceedling’s nudges for CMock strict ordering

The preceding settings are tied to other Ceedling settings; hence, why they are
documented here.

The first setting above, `:enforce_strict_ordering`, defaults to `FALSE` within
CMock. However, it is set to `TRUE` by default in Ceedling as our way of
encouraging you to use strict ordering.

Strict ordering is teeny bit more expensive in terms of code generated, test
execution time, and complication in deciphering test failures. However, it’s
good practice. And, of course, you can always disable it by overriding the
value in the Ceedling project configuration file.

[cmock-docs]: https://github.com/ThrowTheSwitch/CMock/blob/master/docs/CMock_Summary.md
