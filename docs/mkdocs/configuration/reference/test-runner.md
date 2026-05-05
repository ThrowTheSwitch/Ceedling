# `:test_runner`

**Configure test runner generation**

!!! warning
    Unless you have advanced or unique needs, Unity test runner generation
    configuration in Ceedling is generally not needed.

## Test runner overview

The format of Ceedling test files — the C files that contain unit test cases —
is intentionally simple. It’s pure code and all legit C with `#include`
statements, simple functions for test cases, and optional `setUp()` and 
`tearDown()` functions.

To create test executables, we need a `main()` and a variety of calls to the
Unity framework to “hook up” all your test cases into a test suite. You can do
this by hand, of course, but it’s tedious and needed updates as code evolves 
are easily forgotten.

## Unity & test runners

Unity provides a script able to generate a test runner in C for you. It
relies on [Ceedling conventions][ceedling-conventions] used in your test files. 
Ceedling takes this a step further by calling this script for you with all the 
needed parameters.

Test runner generation is configurable. The `:test_runner` section of your
Ceedling project file allows you to pass options to Unity’s runner generation
script. Based on other Ceedling options, Ceedling also sets certain test runner 
generation configuration values for you.

**[Test runner configuration options are documented in the Unity project][unity-runner-options].**

## `:test_runner` ↳ `:cmdline_args`

Before Ceedling 1.0.0, the test runner option `:cmdline_args` was needed 
for certain advanced test suite features. This option is still needed, 
but Ceedling now automatically sets it for you in the scenarios requiring it.

!!! note "Environment limitations"
    Be aware that `:cmdline_args` works well in desktop, native testing but 
    is generally unsupported by emulators running test executables.
    
    The idea of command line arguments passed to an executable is generally 
    only possible with desktop command line terminals.

## Example `:test_runner` YAML

```yaml
:test_runner:
  # Insert additional #include statements in a generated runner
  :includes:
    - Foo.h
    - Bar.h
```

[ceedling-conventions]: ../../testing-guide/conventions.md
[unity-runner-options]: https://github.com/ThrowTheSwitch/Unity/blob/master/docs/UnityHelperScriptsGuide.md#options-accepted-by-generate_test_runnerrb

<br/><br/>
