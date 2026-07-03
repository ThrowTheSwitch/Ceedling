# Conventions & Behaviors

**How to get things done and understand what's happening during builds**

## Directory structure & filenames

Much of Ceedling's functionality is driven by collecting files
matching certain patterns inside the paths it's configured
to search. See the documentation for the `:extension` section
of your configuration file (found in the [configuration reference](../configuration/index.md)) to
configure the file extensions Ceedling uses to match and collect
files. Test file naming is covered later in this section.

Test files and source files must be segregated by directories.
Any directory structure will do. Tests can be held in subdirectories
within source directories, or tests and source directories
can be wholly separated at the top of your project's directory
tree.

## Test build search paths

Test builds in C are fairly complex. Each test file becomes a test
executable. Each test executable needs generated runner code and 
optionally generated mocks. Slicing and dicing what files are 
compiled and linked and how search paths are assembled is tricky
business. That's why Ceedling exists in the first place. Because
of these issues, search paths, in particular, require quite a bit
of special handling.

Unless your project is relying exclusively on `extern` statements and
uses no mocks for testing, Ceedling _**must**_ be told where to find 
header files. Without search path knowledge, mocks cannot be generated, 
and test file compilation will fail for lack of symbol definitions
and function declarations.

Ceedling provides two mechanisms for configuring search paths:

1. The [`:paths` ↳ `:include`](../configuration/reference/paths.md) section within your 
   project file (or mixin files).
1. The [`TEST_INCLUDE_PATH(...)`](build-directives.md#test_include_path) build directive 
   macro. This is only available within test files.

In testing contexts, you have three options for assembling the core of 
the search path list used by Ceedling for test builds:

1. List all search paths within the `:paths` ↳ `:include` subsection 
   of your project file. This is the simplest and most common approach.
1. Create the search paths for each test file using calls to the 
  `TEST_INCLUDE_PATH(...)` build directive macro within each test file.
1. Blending the preceding options. In this approach the subsection
   within your project file acts as a common, base list of search 
   paths while the build directive macro allows the list to be 
   expanded upon for each test file. This method is especially helpful 
   for large and/or complex projects in trimming down 
   problematically long compiler command lines.

As for the complete search path list for test builds created by Ceedling,
it is assembled from a variety of sources. In order:

1. Mock generation build path (if mocking is enabled)
1. Paths provided via `TEST_INCLUDE_PATH(...)` build directive macro
1. Any paths within `:paths` ↳ `:test` list containing header files
1. `:paths` ↳ `:support` list from your project configuration
1. `:paths` ↳ `:include` list from your project configuration
1. `:paths` ↳ `:libraries` list from your project configuration
1. Internal path for Unity's unit test framework C code
1. Internal paths for CMock's C code (if respective feature enabled)
1. `:paths` ↳ `:test_toolchain_include` list from your project 
   configuration

The paths lists above are documented in detail in the discussion of 
project configuration.

_**Notes:**_

* The order of your `:paths` entries directly translates to the ordering
  of search paths.
* The logic of the ordering above is essentially that:
    * Everything above (5) should have precedence to allow test-specific 
     symbols, function signatures, etc. to be found before that of your 
     source code under test. This is the necessary pattern for effective 
     testing and test builds.
    * Everything below (5) is supporting symbols and function signatures
     for your source code. Your source code should be processed before
     these for effective builds generally.
* (3) is a balancing act. It is entirely possible that test developers
  will choose to create common files of symbols and supporting code 
  necessary for unit tests and choose to organize it alongside their 
  test files. A test build must be able to find these references. At the
  same time it is highly unlikely every test directory path in a project
  is necessary for a test build — particularly in large and sophisticated
  projects. To reduce overall search path length and problematic command
  lines, this convention tailors the search path. This is low risk
  tailoring but could cause gotchas in edge cases or when Ceedling is 
  combined with other tools. Any other such tailoring is avoided as it
  could too easily cause maddening build problems.
* Remember that the ordering of search paths is impacted by the merge 
  order of any Mixins. Paths specified with Mixins will be added to 
  path lists in your project configuration in the order of merging.

## Release build search paths

Unlike test builds, release builds are relatively straightforward. Each
source file is compiled into an object file. All object files are linked.
A Ceedling release build may optionally compile and link in CException
and can handle linking in libraries as well.

Search paths for release builds are configured with `:paths` ↳ `:include` 
in your project configuration. That's about all there is to it.

## Source files & release artifacts

Your binary release artifact results from the compilation and
linking of all source files Ceedling finds in the specified source
directories. At present only source files with a single (configurable)
extension are recognized. That is, `*.c` and `*.cc` files will not
both be recognized - only one or the other. See the configuration
options and defaults in the documentation for the `:extension`
sections of your configuration file (found in the [configuration reference](../configuration/index.md)).

## Test files & fixtures

Ceedling builds each individual test file with its accompanying
source file(s) into a single, monolithic test fixture executable.

### Test file naming

Ceedling recognizes test files by a naming convention — a (configurable)
prefix such as "`test_`" at the beginning of the file name with the same 
file extension as used by your C source files. See the configuration options
and defaults in the documentation for the `:project` and `:extension`
sections of your configuration file (found in the [configuration reference](../configuration/index.md)).

Depending on your configuration options, Ceedling can recognize
a variety of test file naming patterns in your test search paths.
For example, `test_some_super_functionality.c`, `TestYourSourceFile.cc`,
or `testing_MyAwesomeCode.C` could each be valid test file
names. Note, however, that Ceedling can recognize only one test
file naming convention per project.

### Source & mock files to compile and link

Ceedling knows what files to compile and link into each individual
test executable by way of the `#include` list contained in each
test file and optional test directive macros.

The `#include` list directs Ceedling in two ways:

1. Any C source files in the configured project directories
   corresponding to `#include`d header files will be compiled and 
   linked into the resulting test fixture executable.
1. If you are using mocks, header files with the appropriate 
   mocking prefix (e.g. `mock_foo.h`) direct Ceedling to find the
   source header file (e.g. `foo.h`), generate a mock from it, and
   compile & link that generated code into into the test executable 
   as well.

Sometimes the source file you need to add to your test executable has
no corresponding header file — e.g. `file_abc.h` contains symbols 
present in `file_xyz.c`. In these cases, you can use the test 
directive macro `TEST_SOURCE_FILE(...)` to tell Ceedling to compile 
and link the desired source file into the test executable (see 
[macro documentation](build-directives.md)).

That was a lot of information and many clauses in a very few 
sentences; the commented example test file code that follows in a 
bit will make it clearer.

### Test case functions & runner generation

By naming your test functions according to convention, Ceedling
will extract and collect into a generated test runner C file the 
appropriate calls to all your test case functions. This runner 
file handles all the execution minutiae so that your test file 
can be quite simple. As a bonus, you'll never forget to wire up 
a test function to be executed.

In this generated runner lives the `main()` entry point for the 
resulting test executable. There are no configurable options for 
the naming convention of your test case functions.

A test case function signature must have these elements:

1. `void` return
1. `void` parameter list
1. A function name prepended with lowercase "`test`".

In other words, a test function signature should look like this: 
`void test<any_name_you_like>(void)`.

## Test preprocessing

### Background and overview

Ceedling and CMock are advanced tools that both perform fairly sophisticated
parsing.

However, neither of these tools fully understands the entire C language,
especially C's preprocessing statements.

If your test files rely on macros and `#ifdef` conditionals used in certain
ways (see examples below), there's a chance that Ceedling will break on trying
to process your test files, or, alternatively, your test suite will build but 
not execute as expected.

Similarly, generating mocks of header files with macros and `#ifdef`
conditionals around or in function signatures can get weird. Of course, it's 
often in sophisticated projects with complex header files that mocking is most 
desired in the first place.

Ceedling includes an optional ability to preprocess the following files before 
then extracting test cases and functions to be mocked with text parsing.

1. Your test files, or
1. Mockable header files, or
1. Both of the above 

See the [`:project` ↳ `:use_test_preprocessor`][project-settings] project 
configuration setting.

This Ceedling feature uses `gcc`'s preprocessing mode and the `cpp` preprocessor 
tool to strip down / expand test files and headers to their raw code content 
that can then be parsed as text by Ceedling and CMock. These tools must be in 
your search path if Ceedling's preprocessing is enabled.

**Ceedling's test preprocessing abilities are directly tied to the features and 
output of `gcc` and `cpp`. The default Ceedling tool definitions for these should 
not be redefined for other toolchains. It is highly unlikely to work for you. 
Future Ceedling improvements will allow for a plugin-style ability to use your 
own tools in this highly specialized capacity.**

[project-settings]: ../configuration/reference/project.md

### Limitations & gotchas

#### Preprocessing limitations cheatsheet

Ceedling's preprocessing abilities are generally quite useful — especially in 
projects with multiple build configurations for different feature sets or 
multiple targets, legacy code that cannot be refactored, and complex header 
files provided by vendors.

However, best applying Ceedling's preprocessing abilities requires understanding 
how the feature works, when to use it, and its limitations.

At a high level, Ceedling's preprocessing is applicable for cases where macros 
or conditional compilation preprocessing statements (e.g. `#ifdef`):

* Generate or hide/reveal your test files' `#include` statements.
* Generate or hide/reveal your test files' test case function signatures 
  (e.g. `void test_foo()`.
* Generate or hide/reveal mockable header files' `#include` statements.
* Generate or hide/reveal header files' mockable function signatures.

**_NOTE:_ You do not necessarily need to enable Ceedling's preprocessing only
because you have preprocessing statements in your test files or mockable header 
files. The feature is only truly needed if your project meets the conditions 
above.**

The sections that follow flesh out the details of the bulleted list above.

#### Preprocessing gotchas

**_IMPORTANT:_ As of Ceedling 1.0.0, Ceedling's test preprocessing feature 
has a limitation that affects Unity features triggered by the following macros.**

* `TEST_CASE()`
* `TEST_RANGE()`

`TEST_CASE()` and `TEST_RANGE()` are Unity macros that are positional in a file 
in relation to the test case functions they modify. While Ceedling's test file
preprocessing can preserve these macro calls, their position cannot be preserved.

That is, Ceedling's preprocessing and these Unity features are not presently 
compatible. Note that it _is_ possible to enable preprocessing for mockable 
header files apart from enabling it for test files. See the documentation for
`:project` ↳ `:use_test_preprocessing`. This can allow test preprocessing in the 
common cases of sophtisticate mockable headers while Unity's `TEST_CASE()` and 
`TEST_RANGE()` are utilized in a test file untouched by preprocessing.

**_IMPORTANT:_ The following new build directive macro `TEST_INCLUDE_PATH()` 
available in Ceedling 1.0.0 is incompatible with enclosing conditional 
compilation C preprocessing statements:**

Wrapping `TEST_INCLUDE_PATH()` in conditional compilation statements 
(e.g. `#ifdef`) will not behave as you expect. This macro is used as a marker
for advanced abilities discovered by Ceedling parsing a test file as plain text.
Whether or not Ceedling preprocessing is enabled, Ceedling will always discover 
this marker macro in the plain text of a test file.

Why is `TEST_INCLUDE_PATH()` incompatible with `#ifdef`? Well, it's because of
a cyclical dependency that cannot be resolved. In order to perform test 
preprocessing, we need a full complement of `#include` search paths. These 
could be provided, in part, by `TEST_INCLUDE_PATH()`. But, if we allow 
`TEST_INCLUDE_PATH()` to be placed within conditional compilation C 
preprocessing statements, our search paths may be different after test 
preprocessing! The only solution is to disallow this and scan a test file as
plain text looking for this macro at the beginning of a test build.

**_Notes:_**

* `TEST_SOURCE_FILE()` _can_ be placed within conditional compilation
  C preprocessing statements.
* `TEST_INCLUDE_PATH()` & `TEST_SOURCE_FILE()` can be "hidden" from Ceedling's
  text scanning with traditional C comments.

### Test file preprocessing

When preprocessing is enabled for test files, Ceedling will expand preprocessor
statements in test files before extracting `#include` conventions and test case 
signatures. That is, preprocessing output is used to generate test runners 
and assemble the components of a test executable build.

!!! tip "Preprocessing Not Needed Inside Test Functions"
    Conditional directives _inside_ test case functions generally do not require
    Ceedling's test preprocessing ability. Assuming your code is correct, the C
    preprocessor within your toolchain will do the right thing for you in your
    test build. Read on for more details and the other cases of interest.

Test file preprocessing by Ceedling is applicable primarily when conditional
preprocessor directives generate the `#include` statements for your test file
and/or generate or enclose full test case functions. Ceedling will not be able 
to properly discover your `#include` statements or test case functions unless 
they are plainly available in an expanded, raw code version of your test file. 
Ceedling's preprocessing abilities provide that expansion.

#### Examples of when Ceedling preprocessing **_is_** needed for test files

Generally, Ceedling preprocessing is needed when:

1. `#include` statements are generated by macros
1. `#include` statements are conditionally present due to `#ifdef` statements
1. Test case function signatures are generated by macros
1. Test case function signatures are conditionaly present due to `#ifdef` statements

```c
// #include conventions are not recognized for anything except #include "..." statements
INCLUDE_STATEMENT_MAGIC("header_file")
```
```c
// Test file scanning will always see this #include statement
#ifdef BUILD_VARIANT_A
#include "mock_FooBar.h"
#endif
```
```c
// Test runner generation scanning will see the test case function signature and think this test case exists in every build variation
#ifdef MY_SUITE_BUILD
void test_some_test_case(void) {
   TEST_ASSERT_EQUALS(...);
}
#endif
```
```c
// Test runner generation will not recognize this as a test case when scanning the file
void TEST_CASE_MAGIC("foo_bar_case") {
   TEST_ASSERT_EQUALS(...);
}
```

#### Examples of when test preprocessing is **_not_** needed for test files

```c
// Code inside a test case is simply code that your toolchain will expand and build as you desire
// You can manage your compile time symbols with the :defines section of your project configuration file
void test_some_test_case(void) {
#ifdef BUILD_VARIANT_A
   TEST_ASSERT_EQUALS(...);
#endif

#ifdef BUILD_VARIANT_B
   TEST_ASSERT_EQUALS(...);
#endif
}
```

### Header file preprocessing

When preprocessing is enabled for mocking, Ceedling will expand preprocessor 
statements in header files before generating mocks from them. CMock requires
a clear look at function definitions and types in order to do its work.

Header files with preprocessor directives and conditional macros can easily
obscure details from CMock's limited C parser. Advanced C projects tend
to rely on preprocessing directives and macros to accomplish everything from
build variants to OS calls to register access to managing proprietary language
extensions.

Mocking is often most useful in complicated codebases. As such Ceedling's 
preprocessing abilities tend to be quite necessary to properly expand header
files so CMock can parse them.

#### Examples of when Ceedling preprocessing **_is_** needed for mockable headers

Generally, Ceedling preprocessing is needed when:

1. Function signatures are formed by macros
1. Function signatures are conditionaly present due to surrounding `#ifdef` 
   statements
1. Macros expand to become function decorators, return types, or parameters 

**_Important Notes:_**

* Sometimes CMock's parsing features can be configured to handle scenarios
  that fall within (3) above. CMock can match and remove most text strings,
  match and replace certain text strings, map custom types to mockable 
  alternatives, and be extended with a Unity helper to handle complex and 
  compound types. See [CMock]'s documentation for more.

* Test preprocessing causes any macros or symbols in a mockable header to 
  "disappear" in the generated mock. It's quite common to have needed symbols
  or macros in a header file that do not directly impact the function 
  signatures to be mocked. This can break compilation of your test suite.

  Possible solutions to this problem include:

    1. Move symbols and macros in your header file that do not impact function 
      signatures to another source header file that will not be filtered
      by Ceedling's header file preprocessing.
    1. If (1) is not possible, you may duplicate the needed symbols and macros
      in a header file that is only available in your test build search paths
      and include it in your test file.

```c
// Header file scanning will see this function signature but mistakenly mock the name of the macro
void FUNCTION_SIGNATURE_MAGIC(...);
```

```c
// Header file scanning will always see this function signature
#ifdef BUILD_VARIANT_A
unsigned int someFunction(void);
#endif
```

```c
// Header file scanning will either fail for this function signature or extract erroneous type names
INLINE_MAGIC RETURN_TYPE_MAGIC someFunction(PARAMETER_MAGIC);
```

## Duration reporting

### Logged run times

Ceedling logs two execution times for every project run.

It first logs the set up time necessary to process your project file, parse code
files, build an internal representation of your project, etc. This duration does
not capture the time necessary to load the Ruby runtime itself.

```
Ceedling set up completed in 223 milliseconds
```

Secondly, each Ceedling run also logs the time necessary to run all the tasks 
you specify at the command line.

```
Ceedling operations completed in 1.03 seconds
```

### Test suite & executable durations

A test suite comprises one or more Unity test executables (see 
[Anatomy of a Test Suite](test-suite-anatomy.md)). Ceedling times indvidual Unity 
test executable run durations. It also sums these into a total test suite 
execution time. These duration values are typically used in generating test 
reports via plugins.

Not all test report formats utilize duration values. For those that do, some
effort is usually required to map Ceedling duration values to a relevant test 
suite abstraction within a given test report format.

Because Ceedling can execute builds with multiple threads, care must be taken
to interpret test suite duration values — particularly in relation to 
Ceedling's logged run times.

In a multi-threaded build it's quite common for the logged Ceedling project run
time to be less than the total suite time in a test report. In multi-threaded 
builds on multi-core machines, test executables are run on different processors
simultaneously. As such, the total on-processor time in a test report can 
exceed the operation time Ceedling itself logs to the console. Further, because
multi-threading tends to introduce context switching and processor scheduling 
overhead, the run duration of a test executable may be reported as longer than
a in a comparable single-threaded build.

### Test case run times

Individual test case exection time tracking is specifically a [Unity] feature 
(see its documentation for more details). If enabled and if your platform 
supports the time mechanism Unity relies on, Ceedling will automatically 
collect test case time values — generally made use of by test report plugins.

To enable test case duration measurements, they must be enabled as a Unity
compilation option. Add `UNITY_INCLUDE_EXEC_TIME` to Unity's compilation
symbols (`:unity` ↳ `:defines`) in your Ceedling project file (see example
below). Unity test case durations as reported by Ceedling default to 0 if the
compilation option is not set.

```yaml
:unity:
  :defines:
    - UNITY_INCLUDE_EXEC_TIME
```

_NOTE:_ Most test cases are quite short, and most computers are quite fast. As
 such, Unity test case execution time is often reported as 0 milliseconds as
 the CPU execution time for a test case typically remains in the microseconds
 range. Unity would require special rigging that is inconsistently available
 across platforms to measure test case durations at a finer resolution.

## Dependency tracking

Previous versions of Ceedling used features of Rake to offer
various kinds of smart rebuilds — that is, only regenerating files, 
recompiling code files, or relinking executables when changes within 
the project had occurred since the last build. Optional Ceedling 
features discovered “deep dependencies” such that, for example, a 
change in a header file several nested layers deep in `#include` 
statements would cause all the correct test executables to be 
updated and run.

These features have been temporarily disabled and/or removed for 
test suites and remain in limited form for release build while
Ceedling undergoes a major overhaul.

Please see the [Release Notes](https://github.com/ThrowTheSwitch/Ceedling/blob/master/docs/ReleaseNotes.md).

### (Not so) smart rebuilds

* New features that are a part of the Ceedling overhaul can 
  significantly speed up test suite execution and release builds 
  despite the present behavior of brute force running all build 
  steps. See the discussion of enabling multi-threaded builds in 
  later sections.

* When smart rebuilds return, they will further speed up builds as
  will other planned optimizations.

## Build output

Ceedling requires a top-level build directory for all the stuff
that it, the accompanying test tools, and your toolchain generate.
That build directory's location is configured in the top-level 
`:project` section of your configuration file (discussed in the
[configuration reference](../configuration/index.md)). There
can be a ton of generated files. By and large, you can live a full
and meaningful life knowing absolutely nothing at all about
the files and directories generated below the root build directory.

As noted already, it's good practice to add your top-level build
directory to source control but nothing generated beneath it.
you'll spare yourself headache if you let Ceedling delete and
regenerate files and directories in a non-versioned corner
of your project's filesystem beneath the top-level build directory.

The `artifacts/` directory is the one and only directory you may
want to know about beneath the top-level build directory. The
subdirectories beneath `artifacts` will hold your binary release
target output (if your project is configured for release builds)
and will serve as the conventional location for plugin output.
This directory structure was chosen specifically because it
tends to work nicely with Continuous Integration setups that
recognize and list build artifacts for retrieval / download.

## Build errors, test failures

### Errors vs. Failures

Ceedling will run a specified build until an **_error_**. An error 
refers to a build step encountering an unrecoverable problem. Files 
not found, nonexistent paths, compilation errors, missing symbols, 
plugin exceptions, etc. are all errors that will cause Ceedling 
to immediately end a build.

A **_failure_** refers to a test failure. That is, an assertion of 
an expected versus actual value failed within a unit test case. 
A test failure will not stop a build. Instead, the suite will run 
to completion with test failures collected and reported along with 
all test case statistics.

### Ceedling Exit Codes

In its default configuration, Ceedling terminates with an exit code 
of `1`:

* On any build error and immediately terminates upon that build 
   error.
* On any test case failure but runs the build to completion and
   shuts down normally.

This behavior can be especially handy in Continuous Integration 
environments where you typically want an automated CI build to break 
upon either build errors or test failures.

If this exit code convention for test failures does not work for you, 
no problem-o. You may be of the mind that running a test suite to 
completion should yield a successful exit code (even if tests failed).
Add the following to your project file to force Ceedling to finish a 
build with an exit code of 0 even upon test case failures.

```yaml
# Ceedling terminates with happy `exit(0)` even if test cases fail
:test_build:
   :graceful_fail: true
```

If you use the option for graceful failures in CI, you'll want to
rig up some kind of logging monitor that scans Ceedling's test
summary report sent to `$stdout` and/or a log file. Otherwise, you
could have a successful build but failing tests.

### Test executable exit codes

Ceedling works by collecting multiple Unity test executables together 
into a test suite (more here: [Anatomy of a Test Suite](test-suite-anatomy.md)).

A Unity test executable's exit code is the number of failed tests. An
exit code of `0` means all tests passed while anything larger than zero
is the number of test failures.

Because of platform limitations on how big an exit code number can be
and because of the logical complexities of distinguishing test failure
counts from build errors or plugin problems, Ceedling conforms to a
much simpler exit code convention than Unity: `0` = 🙂 while `1` = ☹️.

[CMock]: http://github.com/ThrowTheSwitch/CMock
[Unity]: http://github.com/ThrowTheSwitch/Unity

<br/><br/>
