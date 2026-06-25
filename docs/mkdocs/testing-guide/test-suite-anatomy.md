# Anatomy of a Test Suite

A Ceedling test suite is composed of one or more individual test executables.

The [Unity] project provides the actual framework for test case assertions 
and unit test sucess/failure accounting. If mocks are enabled, [CMock] builds 
on Unity to generate mock functions from source header files with expectation
test accounting. Ceedling is the glue that combines these frameworks, your
project's toolchain, and your source code into a collection of test 
executables you can run as a singular suite.

## What is a test executable?

Put simply, in a Ceedling test suite, each test file becomes a test executable.
Your test code file becomes a single test executable.

`test_foo.c` ➡️ `test_foo.out` (or `test_foo.exe` on Windows)

A single test executable generally comprises the following. Each item in this
list is a C file compiled into an object file. The entire list is linked into
a final test executable.

* One or more release C code files under test (`foo.c`)
* `unity.c`.
* A test C code file (`test_foo.c`).
* A generated test runner C code file (`test_foo_runner.c`). `main()` is located
  in the runner.
* If using mocks:
    * `cmock.c`
    * One more mock C code files generated from source header files (`mock_bar.c`)

## Why multiple individual test executables in a suite?

For several reasons:

* This greatly simplifies the building of your tests.
* C lacks any concept of namespaces or reflection abilities able to segment and 
  distinguish test cases.
* This allows the same release code to be built differently under different
  testing scenarios. Think of how different `#define`s, compiler flags, and
  linked libraries might come in handy for different tests of the same 
  release C code. One source file can be built and tested in different ways
  with multiple test files.

## Ceedling's role in your test suite

A test executable is not all that hard to create by hand, but it can be tedious,
repetitive, and error-prone.

What Ceedling provides is an ability to perform the process repeatedly and simply 
at the push of a button, alleviating the tedium and any forgetfulness. Just as 
importantly, Ceedling also does all the work of running each of those test 
executables and tallying all the test results.

[Unity]: http://github.com/ThrowTheSwitch/Unity
[CMock]: http://github.com/ThrowTheSwitch/CMock

<br/><br/>
