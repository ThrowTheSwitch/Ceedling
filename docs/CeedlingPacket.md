
# Ceedling

All code is copyright © 2010-2023 Ceedling Project
by Michael Karlesky, Mark VanderVoord, and Greg Williams.

This Documentation is released under a
[Creative Commons 4.0 Attribution Share-Alike Deed][CC4SA].

[CC4SA]: https://creativecommons.org/licenses/by-sa/4.0/deed.en

# Quick Start

Ceedling is a fancypants build system that greatly simplifies building 
C projects. While it can certainly build release targets, it absolutely 
shines at running unit test suites.

## Steps

1. Install Ceedling
1. Create a project
   1. Use Ceedling to generate an example project, or
   1. Add a Ceedling project file to the root of an existing project, or
   1. Create a project from scratch:
      1. Create a project directory
      1. Add source code and optionally test code however you'd like it organized
      1. Create a Ceedling project file in the root of your project directory
1. Run Ceedling tasks from the working directory of your project

Ceedling requires a command line C toolchain be available in your path. It's 
flexible enough to work with most anything on any platform. By default, Ceedling 
is ready to work with [GCC] out of the box (we recommend the [MinGW] project 
on Windows).

A common build strategy with tooling other than GCC is to use your target 
toolchain for release builds (with or without Ceedling) but rely on Ceedling + 
GCC for test builds (more on all this [here][packet-section-2]).

[GCC]: https://gcc.gnu.org

## Ceedling Tasks

Once you have Ceedling installed and a project file, Ceedling tasks go like this:

* `ceedling test:all`, or
* `ceedling release`, or, if you fancy,
* `ceedling clobber verbosity:obnoxious test:all gcov:all release`

## Quick Start Documentation

* [Installation][quick-start-1]
* [Sample test code file + Example Ceedling projects][quick-start-2]
* [Simple Ceedling project file][quick-start-3]
* [Ceedling at the command line][quick-start-4]
* [All your Ceedling project file options][quick-start-5]

[quick-start-1]: #ceedling-installation--set-up
[quick-start-2]: #commented-sample-test-file
[quick-start-3]: #simple-sample-project-file
[quick-start-4]: #now-what-how-do-i-make-it-go
[quick-start-5]: #the-almighty-project-configuration-file-in-glorious-yaml

<br/>

---

# Contents

(Be sure to review **[breaking changes](BreakingChanges.md)** if you are working with
a new release of Ceedling.)

Building test suites in C requires much more scaffolding than for
a release build. As such, much of Ceedling's documentation is concerned
with test builds. But, release build documentation is here too. We promise.
It's just all mixed together.

1. **[Ceedling, a C Build System for All Your Mad Scientisting Needs][packet-section-1]**

   This section provides lots of background, definitions, and links for Ceedling
   and its bundled frameworks. It also presents a very simple, example Ceedling
   project file.

1. **[Ceedling, Unity, and CMock’s Testing Abilities][packet-section-2]**

   This section speaks to the philosophy of and practical options for unit testing
   code in a variety of scenarios.

1. **[How Does a Test Case Even Work?][packet-section-3]**

   A brief overview of what a test case is and several simple examples illustrating
   how test cases work.

1. **[Commented Sample Test File][packet-section-4]**

   This sample test file illustrates how to create test cases as well as many of the
   conventions that Ceedling relies on to do its work. There's also a brief 
   discussion of what gets compiled and linked to create an executable test.

1. **[Anatomy of a Test Suite][packet-section-5]**

   This documentation explains how a unit test grows up to become a test suite.

1. **[Ceedling Installation & Set Up][packet-section-6]**

   This one is pretty self explanatory.

1. **[Now What? How Do I Make It _GO_?][packet-section-7]**

   Ceedling's many command line tasks and some of the rules about using them.

1. **[Important Conventions & Behaviors][packet-section-8]**

   Much of what Ceedling accomplishes — particularly in testing — is by convention. 
   Code and files structured in certain ways trigger sophisticated Ceedling features. 

1. **[Using Unity, CMock & CException][packet-section-9]**

   Not only does Ceedling direct the overall build of your code, it also links 
   together several key tools and frameworks. Those can require configuration of 
   their own. Ceedling facilitates this.

1. **[The Almighty Ceedling Project Configuration File (in Glorious YAML)][packet-section-10]**

   This is the exhaustive documentation for all of Ceedling's project file 
   configuration options — from project paths to command line tools to plugins and
   much, much more.

1. **[Build Directive Macros][packet-section-11]**

   These code macros can help you accomplish your build goals When Ceedling's 
   conventions aren't enough.

1. **[Ceedling Plugins][packet-section-12]**

   Ceedling is extensible. It includes a number of built-in plugins for code coverage,
   test report generation, continuous integration reporting, test file scaffolding 
   generation, sophisticated release builds, and more.

1. **[Global Collections][packet-section-13]**

   Ceedling is built in Ruby. Collections are globally available Ruby lists of paths,
   files, and more that can be useful for advanced customization of a Ceedling project 
   file or in creating plugins.

[packet-section-1]:  #ceedling-a-c-build-system-for-all-your-mad-scientisting-needs
[packet-section-2]:  #ceedling-unity-and-c-mocks-testing-abilities
[packet-section-3]:  #how-does-a-test-case-even-work
[packet-section-4]:  #commented-sample-test-file
[packet-section-5]:  #anatomy-of-a-test-suite
[packet-section-6]:  #ceedling-installation--set-up
[packet-section-7]:  #now-what-how-do-i-make-it-go
[packet-section-8]:  #important-conventions--behaviors
[packet-section-9]:  #using-unity-cmock--cexception
[packet-section-10]: #the-almighty-ceedling-project-configuration-file-in-glorious-yaml
[packet-section-11]: #build-directive-macros
[packet-section-12]: #ceedling-plugins
[packet-section-13]: #global-collections

---

<br/>

# Ceedling, a C Build System for All Your Mad Scientisting Needs

Ceedling allows you to generate an entire test and release build 
environment for a C project from a single, short YAML configuration 
file.

Ceedling and its bundled tools, Unity, CMock, and CException, don't 
want to brag, but they're also quite adept at supporting the tiniest of 
embedded processors, the beefiest 64-bit powerhouses available, and 
everything in between.

Assembling build environments for C projects — especially with
automated unit tests — is a pain. No matter the all-purpose build 
environment tool you use, configuration is tedious and requires 
considerable glue code to pull together the necessary tools and 
libraries to run unit tests. The Ceedling bundle handles all this 
for you.

## Simple Sample Project File

For a project including Unity/CMock unit tests and using the default 
toolchain `gcc`, the configuration file could be as simple as this:

```yaml
:project:
  :build_root: project/build/
  :release_build: TRUE

:paths:
  :test:
    - tests/**
  :source:
    - source/**
  :include:
    - inc/**
```

From the command line, to run all your unit tests, you would run 
`ceedling test:all`. To build the release version of your project,
you would simply run `ceedling release`. That's it!

Of course, many more advanced options allow you to configure
your project with a variety of features to meet a variety of needs.
Ceedling can work with practically any command line toolchain
and directory structure – all by way of the configuration file.
Further, because Ceedling piggybacks on Rake, you can add your
own Rake tasks to accomplish project tasks outside of testing
and release builds. A facility for plugins also allows you to
extend Ceedling's capabilities for needs such as custom code
metrics reporting and coverage testing.

## What’s with This Name?

Glad you asked. Ceedling is tailored for unit tested C projects
and is built upon Rake (a Make replacement implemented in the Ruby 
scripting language). So, we've got C, our Rake, and the fertile 
soil of a build environment in which to grow and tend your project 
and its unit tests. Ta da - _Ceedling_.

## What Do You Mean “Tailored for unit tested C projects”?

Well, we like to write unit tests for our C code to make it lean and
mean — that whole [Test-Driven Development][tdd] thing.

Along the way, this style of writing C code spawned two
tools to make the job easier:

1. A unit test framework for C called _Unity_
1. A mocking library called _CMock_

And, though it's not directly related to testing, a C framework for 
exception handling called _CException_ also came along.

[tdd]: http://en.wikipedia.org/wiki/Test-driven_development

These tools and frameworks are great, but they require quite
a bit of environment support to pull them all together in a convenient,
usable fashion. We started off with Rakefiles to assemble everything.
These ended up being quite complicated and had to be hand-edited
or created anew for each new project. Ceedling replaces all that
tedium and rework with a configuration file that ties everything
together.

Though Ceedling is tailored for unit testing, it can also go right 
ahead and build your final binary release artifact for you as well. 
That said, Ceedling is more powerful as a unit test build environment 
than it is a general purpose release build environment. Complicated 
projects including separate bootloaders or multiple library builds, 
etc. are not necessarily its strong suit (but the 
[`subprojects`](../plugins/subprojects/README.md) plugin can 
accomplish quite a bit here).

It's quite common and entirely workable to host Ceedling and your 
test suite alongside your existing release build setup. That is, you 
can use make, Visual Studio, SCons, Meson, etc. for your release build
and Ceedling for your test build. Your two build systems will simply
“point“ to the same project code.

## Hold on. Back up. Ruby? Rake? YAML? Unity? CMock? CException?

Seems overwhelming? It's not bad at all. And, for the benefits testing
bring us, it's all worth it.

### Ruby

[Ruby] is a handy scripting language like Perl or Python. It's a modern, 
full featured language that happens to be quite handy for accomplishing 
tasks like code generation or automating one's workflow while developing 
in a compiled language such as C.

[Ruby]: http://www.ruby-lang.org/en/

### Rake

[Rake] is a utility written in Ruby for accomplishing dependency 
tracking and task automation common to building software. It's a modern, 
more flexible replacement for [Make]).

Rakefiles are Ruby files, but they contain build targets similar
in nature to that of Makefiles (but you can also run Ruby code in
your Rakefile).

[Rake]: http://rubyrake.org/
[Make]: http://en.wikipedia.org/wiki/Make_(software)

### YAML

[YAML] is a "human friendly data serialization standard for all
programming languages." It's kinda like a markup language but don't
call it that. With a YAML library, you can [serialize] data structures
to and from the file system in a textual, human readable form. Ceedling
uses a serialized data structure as its configuration input.

YAML has some advanced features that can greatly 
[reduce duplication][yaml-anchors-aliases] in a configuration file 
needed in complex projects. YAML anchors and aliases are beyond the scope
of this document but may be of use to advanced Ceedling users. Note that 
Ceedling does anticipate the use of YAML aliases. It proactively flattens 
YAML lists to remove any list nesting that results from the convenience of
aliasing one list inside another.

[YAML]: http://en.wikipedia.org/wiki/Yaml
[serialize]: http://en.wikipedia.org/wiki/Serialization
[yaml-anchors-aliases]: https://blog.daemonl.com/2016/02/yaml.html

### Unity

[Unity] is a [unit test framework][unit-testing] for C. It provides facilities
for test assertions, executing tests, and collecting / reporting test
results. Unity derives its name from its implementation in a single C
source file (plus two C header files) and from the nature of its
implementation - Unity will build in any C toolchain and is configurable
for even the very minimalist of processors.

[Unity]: http://github.com/ThrowTheSwitch/Unity
[unit-testing]: http://en.wikipedia.org/wiki/Unit_testing

### CMock

[CMock]<sup>†</sup> is a tool written in Ruby able to generate [function mocks & stubs][test-doubles] 
in C code from a given C header file. Mock functions are invaluable in 
[interaction-based unit testing][interaction-based-tests].
CMock's generated C code uses Unity.

<sup>†</sup> Through a [plugin][FFF-plugin], Ceedling also supports
[FFF], _Fake Function Framework_, for [fake functions][test-doubles] as an
alternative to CMock’s mocks and stubs.

[CMock]: http://github.com/ThrowTheSwitch/CMock
[test-doubles]: https://blog.pragmatists.com/test-doubles-fakes-mocks-and-stubs-1a7491dfa3da
[FFF]: https://github.com/meekrosoft/fff
[FFF-plugin]: ../plugins/fff
[interaction-based-tests]: http://martinfowler.com/articles/mocksArentStubs.html

### CException

[CException] is a C source and header file that provide a simple
[exception mechanism][exn] for C by way of wrapping up the
[setjmp / longjmp][setjmp] standard library calls. Exceptions are a much
cleaner and preferable alternative to managing and passing error codes
up your return call trace.

[CException]: http://github.com/ThrowTheSwitch/CException
[exn]: http://en.wikipedia.org/wiki/Exception_handling
[setjmp]: http://en.wikipedia.org/wiki/Setjmp.h

## Notes on Ceedling Dependencies and Bundled Tools

* By using the preferred installation option of the Ruby Ceedling gem (see 
  later installation section), all other Ceedling dependencies will be 
  installed for you.

* Regardless of installation method, Unity, CMock, and CException are bundled 
  with Ceedling. Ceedling is designed to glue them all together for your 
  project as seamlessly as possible.

* YAML support is included with Ruby. It requires no special installation
  or configuration. If your project file contains properly formatted YAML
  with the recognized names and options (see later sections), you are good 
  to go.

<br/>

# Ceedling, Unity, and CMock’s Testing Abilities

The unit testing Ceedling, Unity, and CMock afford works in practically 
any context.

The simplest sort of test suite is one crafted to run on the same host 
system using the same toolchain as the release artifact under development.

But, Ceedling, Unity, and CMock were developed for use on a wide variety 
of systems and include features handy for low-level system development work.
This is especially of interest to embedded systems developers.

## All your sweet, sweet test suite options

Ceedling, Unity, and CMock help you create and run test suites using any 
of the following approaches. For more on this topic, please see this 
[handy dandy article][tts-which-build] and/or follow the links for each 
item listed below.

[tts-which-build]: https://throwtheswitch.org/build/which

1. **[Native][tts-build-native].** This option builds and runs code on your 
   host system.
   1. In the simplest case this means you are testing code that is intended
      to run on the same sort of system as the test suite. Your test 
      compiler toolchain is the same as your release compiler toolchain.
   1. However, a native build can also mean your test compiler is different
      than your release compiler. With some thought and effort, code for
      another platform can be tested on your host system. This is often
      the best approach for embedded and other specialized development.
1. **[Emulator][tts-build-cross].** In this option, you build your test code with your target's
   toolchain, and then run the test suite using an emulator provided for
   that target. This is a good option for embedded and other specialized
   development — if an emulator is available.
1. **[On target][tts-build-cross].** The Ceedling bundle of tools can create test suites that
   run on a target platform directly. Particularly in embedded development
   — believe it or not — this is often the option of last resort. That is,
   you should probably go with the other options in this list.

[tts-build-cross]: https://throwtheswitch.org/build/cross 
[tts-build-native]: https://throwtheswitch.org/build/native

<br/>

# How Does a Test Case Even Work?

## Behold assertions

In its simplest form, a test case is just a C function with no 
parameters and no return value that packages up logical assertions. 
If no assertions fail, the test case passes. Technically, an empty
test case function is a passing test since there can be no failing
assertions.

Ceedling relies on the [Unity] project for its unit test framework
(i.e. the thing that provides assertions and counts up passing
and failing tests).

An assertion is simply a logical comparison of expected and actual
values. Unity provides a wide variety of different assertions to 
cover just about any scenario you might encounter. Getting 
assertions right is actually a bit tricky. Unity does all that 
hard work for you and has been thoroughly tested itself and battle
hardened through use by many, many developers.

### Super simple passing test case

```c
#include "unity.h"

void test_case(void) {
   TEST_ASSERT_TRUE( (1 == 1) );
}
```

### Super simple failing test case

```c
#include "unity.h"

void test_a_different_case(void) {
   TEST_ASSERT_TRUE( (1 == 2) );
}
```

### Realistic simple test case

In reality, we're probably not testing the static value of an integer 
against itself. Instead, we're calling functions in our source code
and making assertions against return values.

```c
#include "unity.h"
#include "my_math.h"

void test_some_sums(void) {
   TEST_ASSERT_EQUALS(   5, mySum(  2,   3) );
   TEST_ASSERT_EQUALS(   6, mySum(  0,   6) );
   TEST_ASSERT_EQUALS( -12, mySum( 20, -32) );
}
```

If an assertion fails, the test case fails. As soon as an assertion
fails, execution within that test case stops.

Multiple test cases can live in the same test file. When all the
test cases are run, their results are tallied into simple pass
and fail metrics with a bit of metadata for failing test cases such 
as line numbers and names of test cases.

Ceedling and Unity work together to both automatically run your test
cases and tally up all the results.

### Sample test case output

Successful test suite run:

```
--------------------
OVERALL TEST SUMMARY
--------------------
TESTED:  49
PASSED:  49
FAILED:   0
IGNORED:  0
```

A test suite with a failing test:

```
-------------------
FAILED TEST SUMMARY
-------------------
[test/TestModel.c]
  Test: testInitShouldCallSchedulerAndTemperatureFilterInit
  At line (21): "Function TaskScheduler_Init() called more times than expected."

--------------------
OVERALL TEST SUMMARY
--------------------
TESTED:  49
PASSED:  48
FAILED:   1
IGNORED:  0
```

### Advanced test cases with mocks

Often you want to test not just what a function returns but how
it interacts with other functions.

The simple test cases above work well at the "edges" of a 
codebase (libraries, state management, some kinds of I/O, etc.). 
But, in the messy middle of your code, code calls other code. 
One way to handle testing this is with [mock functions][mocks] and
[interaction-based testing][interaction-based-tests].

Mock functions are functions with the same interface as the real 
code the mocks replace. A mocked function allows you to control 
how it behaves and wrap up assertions within a higher level idea 
of expectations.

What is meant by an expectation? Well… We _expect_ a certain 
function is called with certain arguments and that it will return
certain values. With the appropriate code inside a mocked function 
all of this can be managed and checked.

You can write your own mocks, of course. But, it's generally better 
to rely on something else to do it for you. Ceedling uses the [CMock] 
framework to perform mocking for you.

Here's some sample code you might want to test:

```c
#include "other_code.h"

void doTheThingYo(mode_t input) {
   mode_t result = processMode(input);
   if (result == MODE_3) {
      setOutput(OUTPUT_F);
   }
   else {
      setOutput(OUTPUT_D);
   } 
}
```

And, here's what test cases using mocks for that code could look 
like:

```c
#include "mock_other_code.h"

void test_doTheThingYo_should_enableOutputF(void) {
   // Mocks
   processMode_ExpectAndReturn(MODE_1, MODE_3);
   setOutput_Expect(OUTPUT_F);

   // Function under test
   doTheThingYo(MODE_1);
}

void test_doTheThingYo_should_enableOutputD(void) {
   // Mocks
   processMode_ExpectAndReturn(MODE_2, MODE_4);
   setOutput_Expect(OUTPUT_D);

   // Function under test
   doTheThingYo(MODE_2);
}
```

Remember, the generated mock code you can't see here has a whole bunch 
of smarts and Unity assertions inside it. CMock scans header files and
then generates mocks (C code) from the function signatures it finds in
those header files. It's kinda magical.

### That was the basics, but you’ll need more

For more on the assertions and mocking shown above, consult the 
documentation for [Unity] and [CMock] or the resources in
Ceedling's [README][/README.md].

Ceedling, Unity, and CMock rely on a variety of
[conventions to make your life easier][conventions-and-behaviors].
Read up on these to understand how to build up test cases
and test suites.

Also take a look at the very next sections for more examples
and details on how everything fits together.

[conventions-and-behaviors]: #important-conventions--behaviors

<br/>

# Commented Sample Test File

**Here is a beautiful test file to help get you started…**

## Core concepts in code

After absorbing this sample code, you'll have context for much
of the documentation that follows.

The sample test file below demonstrates the following:

1. Making use of the Unity & CMock test frameworks.
1. Adding the source under test (`foo.c`) to the final test 
   executable by convention (`#include "foo.h"`).
1. Adding two mocks to the final test executable by convention
   (`#include "mock_bar.h` and `#include "mock_baz.h`).
1. Adding a source file with no matching header file to the test 
   executable with a test build directive macro 
   `TEST_SOURCE_FILE("more.c")`.
1. Creating two test cases with mock expectations and Unity
   assertions.

All other conventions and features are documented in the sections
that follow.

```c
// test_foo.c -----------------------------------------------
#include "unity.h"     // Compile/link in Unity test framework
#include "types.h"     // Header file with no *.c file -- no compilation/linking
#include "foo.h"       // Corresponding source file, foo.c, under test will be compiled and linked
#include "mock_bar.h"  // bar.h will be found and mocked as mock_bar.c + compiled/linked in;
#include "mock_baz.h"  // baz.h will be found and mocked as mock_baz.c + compiled/linked in

TEST_SOURCE_FILE("more.c") // foo.c depends on symbols from more.c, but more.c has no matching more.h

void setUp(void) {}    // Every test file requires this function;
                       // setUp() is called by the generated runner before each test case function

void tearDown(void) {} // Every test file requires this function;
                       // tearDown() is called by the generated runner after each test case function

// A test case function
void test_Foo_Function1_should_Call_Bar_AndGrill(void)
{
    Bar_AndGrill_Expect();                    // Function from mock_bar.c that instructs our mocking 
                                              // framework to expect Bar_AndGrill() to be called once
    TEST_ASSERT_EQUAL(0xFF, Foo_Function1()); // Foo_Function1() is under test (Unity assertion):
                                              //  (a) Calls Bar_AndGrill() from bar.h
                                              //  (b) Returns a byte compared to 0xFF
}

// Another test case function
void test_Foo_Function2_should_Call_Baz_Tec(void)
{
    Baz_Tec_ExpectAnd_Return(1);       // Function from mock_baz.c that instructs our mocking
                                       // framework to expect Baz_Tec() to be called once and return 1
    TEST_ASSERT_TRUE(Foo_Function2()); // Foo_Function2() is under test (Unity assertion)
                                       //  (a) Calls Baz_Tec() in baz.h
                                       //  (b) Returns a value that can be compared to boolean true
}

// end of test_foo.c ----------------------------------------
```

## Ceedling actions from the sample test code

From the test file specified above Ceedling will generate 
`test_foo_runner.c`. This runner file will contain `main()` and will call 
both of the example test case functions.

The final test executable will be `test_foo.exe` (Windows) or `test_foo.out` 
for Unix-based systems (extensions are configurable. Based on the `#include` 
list and test directive macro above, the test executable will be the output 
of the linker having processed `unity.o`, `foo.o`, `mock_bar.o`, `mock_baz.o`, 
`more.o`, `test_foo.o`, and `test_foo_runner.o`. 

Ceedling finds the needed code files, generates mocks, generates a runner, 
compiles all the code files, and links everything into the test executable. 
Ceedling will then run the test executable and collect test results from it 
to be reported to the developer at the command line.

## Incidentally, Ceedling comes with example projects

If you run Ceedling without a project file (that is, from a working directory 
with no project file present), you can generate entire example projects.

- `ceedling examples` to list available example projects
- `ceedling example <project> [destination]` to generate the 
  named example project

<br/>

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

## Ceedling’s role in your test suite

A test executable is not all that hard to create by hand, but it can be tedious,
repetitive, and error-prone.

What Ceedling provides is an ability to perform the process repeatedly and simply 
at the push of a button, alleviating the tedium and any forgetfulness. Just as 
importantly, Ceedling also does all the work of running each of those test 
executables and tallying all the test results.

<br/>

# Ceedling Installation & Set Up

**How Exactly Do I Get Started?**

The simplest way to get started is to install Ceedling as a Ruby gem. Gems are
simply prepackaged Ruby-based software. Other options exist, but they are most
useful for developing Ceedling 

## As a [Ruby gem](http://docs.rubygems.org/read/chapter/1):

1. [Download and install Ruby][ruby-install]. Ruby 3 is required.

1. Use Ruby's command line gem package manager to install Ceedling:
   `gem install ceedling`. Unity, CMock, and CException come along with 
   Ceedling at no extra charge.

1. Execute Ceedling at command line to create example project
   or an empty Ceedling project in your filesystem (executing
   `ceedling help` first is, well, helpful).

[ruby-install]: http://www.ruby-lang.org/en/downloads/

### Gem install notes

Steps 1-2 are a one time affair for your local environment. When steps 1-2 
are completed once, only step 3 is needed for each new project.

## Getting Started after Ceedling is Installed

1. Once Ceedling is installed, you'll want to start to integrate it with new
   and old projects alike. If you wanted to start to work on a new project
   named `foo`, Ceedling can create the skeleton of the project using `ceedling
   new foo`. Likewise if you already have a project named `bar` and you want to
   integrate Ceedling into it, you would run `ceedling new bar` and Ceedling
   will create any files and directories it needs to run.

1. Now that you have Ceedling integrated with a project, you can start using it.
   A good starting point to get use to Ceedling either in a new project or an
   existing project is creating a new module to get use to Ceedling by issuing
   the command `ceedling module:create[unicorn]`.

## Grab Bag of Ceedling Notes

1. Certain advanced features of Ceedling rely on `gcc` and `cpp`
   as preprocessing tools. In most Linux systems, these tools
   are already available. For Windows environments, we recommend
   the [MinGW project](http://www.mingw.org/) (Minimalist
   GNU for Windows). This represents an optional, additional
   setup / installation step to complement the list above. Upon
   installing MinGW ensure your system path is updated or set
   `:environment` ↳ `:path` in your project file (see
   `:environment` section later in this document).

1. To use a project file name other than the default `project.yml`
   or place the project file in a directory other than the one
   in which you'll run Rake, create an environment variable
   `CEEDLING_MAIN_PROJECT_FILE` with your desired project
   file path.

1. To better understand Rake conventions, Rake execution,
   and Rakefiles, consult the [Rake tutorial, examples, and
   user guide](http://rubyrake.org/).

1. When using Ceedling in Windows environments, a test file name may
   not include the sequences “patch” or “setup”. The Windows Installer
   Detection Technology (part of UAC), requires administrator
   privileges to execute file names with these strings.

<br/>

# Now What? How Do I Make It _GO_?

We're getting a little ahead of ourselves here, but it's good
context on how to drive this bus. Everything is done via the command
line. We'll cover conventions and how to actually configure
your project in later sections.

To run tests, build your release artifact, etc., you will be interacting
with Rake under the hood on the command line. Ceedling works with Rake 
to present you with named tasks that coordinate the file generation and
build steps needed to accomplish something useful. You can also
add your own independent Rake tasks or create plugins to extend
Ceedling (more on this later).

## Ceedling command line tasks

* `ceedling [no arguments]`:

  Run the default Rake task (conveniently recognized by the name default
  by Rake). Neither Rake nor Ceedling provide a default task. Rake will
  abort if run without arguments when no default task is defined. You can
  conveniently define a default task in the Rakefile discussed in the
  preceding setup & installation section of this document.

* `ceedling -T`:

  List all available Rake tasks with descriptions (Rake tasks without
  descriptions are not listed). -T is a command line switch for Rake and
  not the same as tasks that follow.

* `ceedling environment`:

  List all configured environment variable names and string values. This
  task is helpful in verifying the evaluation of any Ruby expressions in
  the `:environment` section of your config file. *Note: Ceedling may
  set some convenience environment variables by default.*

* `ceedling paths:*`:

  List all paths collected from `:paths` entries in your YAML config
  file where `*` is the name of any section contained in `:paths`. This
  task is helpful in verifying the expansion of path wildcards / globs
  specified in the `:paths` section of your config file.

* `ceedling files:assembly`
* `ceedling files:header`
* `ceedling files:source`
* `ceedling files:support`
* `ceedling files:test`

  List all files and file counts collected from the relevant search
  paths specified by the `:paths` entries of your YAML config file. The
  `files:assembly` task will only be available if assembly support is
  enabled in the `:release_build` section of your configuration file.

* `ceedling options:*`:

  Load and merge configuration settings into the main project
  configuration. Each task is named after a `*.yml` file found in the
  configured options directory. See documentation for the configuration
  setting `:project` ↳ `:options_paths` and for options files in advanced
  topics.

* `ceedling test:all`:

  Run all unit tests (rebuilding anything that's changed along the way).

* `ceedling test:build_only`:

  Build all unit tests, object files and executable but not run them.

* `ceedling test:*`:

  Execute the named test file or the named source file that has an
  accompanying test. No path. Examples: `ceedling test:foo`, `ceedling 
  test:foo.c` or `ceedling test:test_foo.c`

* `ceedling test:pattern[*]`:

  Execute any tests whose name and/or path match the regular expression
  pattern (case sensitive). Example: `ceedling "test:pattern[(I|i)nit]"` will
  execute all tests named for initialization testing. Note: quotes may
  be necessary around the ceedling parameter to distinguish regex characters
  from command line operators.

* `ceedling test:path[*]`:

  Execute any tests whose path contains the given string (case
  sensitive). Example: `ceedling test:path[foo/bar]` will execute all tests
  whose path contains foo/bar. Note: both directory separator characters
  / and \ are valid.

* `ceedling test:* --test_case=<test_case_name> `
  Execute test cases which do not match **`test_case_name`**. This option
  is available only after setting  `:cmdline_args` to `true` under 
  `:test_runner` in the project file:
    
    ```yaml
    :test_runner:
      :cmdline_args: true
    ```

  For instance, if you have a test file test_gpio.c containing the following 
  test cases (test cases are simply `void test_name(void)`:

    - `test_gpio_start`
    - `test_gpio_configure_proper`
    - `test_gpio_configure_fail_pin_not_allowed`

  … and you want to run only _configure_ tests, you can call:

    `ceedling test:gpio --test_case=configure`

  **Test case matching notes**

    Test case matching is on sub-strings. `--test_case=configure` matches on
    the test cases including the word _configure_, naturally. 
    `--test_case=gpio` would match all three test cases.


* `ceedling test:* --exclude_test_case=<test_case_name> `
  Execute test cases which do not match **`test_case_name`**. This option
  is available only after setting  `:cmdline_args` to `true` under 
  `:test_runner` in the project file:
    
    ```yaml
    :test_runner:
      :cmdline_args: true
    ```

  For instance, if you have file test_gpio.c with defined 3 tests:

    - `test_gpio_start`
    - `test_gpio_configure_proper`
    - `test_gpio_configure_fail_pin_not_allowed`

  … and you want to run only start tests, you can call:

    `ceedling test:gpio --exclude_test_case=configure`

  **Test case exclusion matching notes**

    Exclude matching follows the same sub-string logic as discussed in the
    preceding section.

* `ceedling release`:

  Build all source into a release artifact (if the release build option
  is configured).

* `ceedling release:compile:*`:

  Sometimes you just need to compile a single file dagnabit. Example:
  `ceedling release:compile:foo.c`

* `ceedling release:assemble:*`:

  Sometimes you just need to assemble a single file doggonit. Example:
  `ceedling release:assemble:foo.s`

* `ceedling module:create[Filename]`:
* `ceedling module:create[<Path:>Filename]`:

  It's often helpful to create a file automatically. What's better than
  that? Creating a source file, a header file, and a corresponding test
  file all in one step!

  There are also patterns which can be specified to automatically generate
  a bunch of files. Try `ceedling module:create[Poodles,mch]` for example!

  The module generator has several options you can configure.
  F.e. Generating the source/header/test file in a sub-directory (by adding 
  <Path> when calling `module:create`). For more info, refer to the 
  [Module Generator][#module-generator] section.

* `ceedling module:stub[Filename]`:
* `ceedling module:stub[<Path:>Filename]`:

  So what happens if you've created your API in your header (maybe even using
  TDD to do so?) and now you need to start to implement the corresponding C
  module? Why not get a head start by using `ceedling module:stub[headername]`
  to automatically create a function skeleton for every function declared in
  that header? Better yet, you can call this again whenever you add new functions
  to that header to add just the new functions, leaving the old ones alone!

* `ceedling logging <tasks...>`:

  Enable logging to <build path>/logs. Must come before test and release
  tasks to log their steps and output. Log names are a concatenation of
  project, user, and option files loaded. User and option files are
  documented in another section.

* `ceedling verbosity[x] <tasks...>`:

  Change default verbosity level. `[x]` ranges from `0` (quiet) to `4`
  (obnoxious) with `5` reserved for debugging output. Level `3` is the 
  default. 
  
  The verbosity task must precede all tasks in the command line task list 
  for which output is desired to be seen. Verbosity settings are generally 
  most meaningful in conjunction with test and release tasks.

* `ceedling verbosity:<level> <tasks...>`:

  Alternative verbosity task scheme using the name of each level.

  | Numeric Level | Named Level         |
  |---------------|---------------------|
  | verbosity[0]  | verbosity:silent    |
  | verbosity[1]  | verbosity:errors    |
  | verbosity[2]  | verbosity:warnings  |
  | verbosity[3]  | verbosity:normal    |
  | verbosity[4]  | verbosity:obnoxious |
  | verbosity[5]  | verbosity:debug     |

* `ceedling summary`:

  If plugins are enabled, this task will execute the summary method of
  any plugins supporting it. This task is intended to provide a quick
  roundup of build artifact metrics without re-running any part of the
  build.

* `ceedling clean`:

  Deletes all toolchain binary artifacts (object files, executables),
  test results, and any temporary files. Clean produces no output at the
  command line unless verbosity has been set to an appreciable level.

* `ceedling clobber`:

  Extends clean task's behavior to also remove generated files: test
  runners, mocks, preprocessor output. Clobber produces no output at the
  command line unless verbosity has been set to an appreciable level.

* `ceedling options:export`:

  This allows you to export a snapshot of your current tool configuration
  as a yaml file. You can specify the name of the file in brackets `[blah.yml]`
  or let it default to `tools.yml`. In either case, the contents of the file 
  can be used as the tool configuration for your project if desired, and 
  modified as you wish.

## Ceedling Command Line Tasks, Extra Credit

### Rake

To better understand Rake conventions, Rake execution, and
Rakefiles, consult the [Rake tutorial, examples, and user guide][rake-guide].

[rake-guide]: http://rubyrake.org/

### File Tasks Are Not Advertised

Individual test and release file tasks are not listed in `-T` output. 
Because so many files may be present it's unwieldy to list them all.

### Combining Tasks At the Command Line

Multiple Rake tasks can be executed at the command line.

For example, `ceedling
clobber test:all release` will remove all generated files;
build and run all tests; and then build all source — in that order.
If any task fails along the way, execution halts before the
next task.

Task order is executed as provided and can be important! This is a 
limitation of Rake. For instance, you won't get much useful information 
from executing `ceedling test:foo 'verbosity[4]'`. Instead, you 
probably want `ceedling 'verbosity[4]' test:foo`.

### Build Directory and Revision Control

The `clobber` task removes certain build directories in the
course of deleting generated files. In general, it's best not
to add to source control any Ceedling generated directories
below the root of your top-level build directory. That is, leave
anything Ceedling & its accompanying tools generate out of source
control (but go ahead and add the top-level build directory that
holds all that stuff if you want).

<br/>

# Important Conventions & Behaviors

**How to get things done and understand what’s happening during builds**

## Directory Structure, Filenames & Extensions

Much of Ceedling's functionality is driven by collecting files
matching certain patterns inside the paths it's configured
to search. See the documentation for the `:extension` section
of your configuration file (found later in this document) to
configure the file extensions Ceedling uses to match and collect
files. Test file naming is covered later in this section.

Test files and source files must be segregated by directories.
Any directory structure will do. Tests can be held in subdirectories
within source directories, or tests and source directories
can be wholly separated at the top of your project's directory
tree.

## Search Path / File Collection Ordering

Path order is important and needed by various functions. Ceedling
itself needs a path order to find files such as header files
that get mocked. Tasks are often ordered by the contents of file 
collections Ceedling builds. Toolchains rely on a search path 
order to compile code.

Paths are organized and prioritized like this:

1. Test paths
1. Support paths
1. Source paths
1. Source include paths

Of course, this list is context dependent. A release build pays
no attention to test or support paths. And, as is documented 
elsewhere, header file search paths do not incorporate source 
file paths.

This ordering can be useful to the user in certain testing scenarios 
where we desire Ceedling or a compiler to find a stand-in header 
file in our support directory before the actual source header 
file of the same name in the source include path list.

If you define your own tools in the project configuration file (see 
the `:tools` section documented later in this here document), you have 
some control over what directories are searched and in what order.

## Configuring Your Header File Search Paths

Unless your project is relying exclusively on `extern` statements and
uses no mocks for testing, Ceedling _**must**_ be told where to find 
header files. Without search path knowledge, mocks cannot be generated, 
and code cannot be compiled.

Ceedling provides two mechanisms for configuring header file 
search paths:

1. The [`:paths` ↳ `:include`](#paths--include) section within your 
   project file. This is available to both test and release builds.
1. The [`TEST_INCLUDE_PATH(...)`](#test_include_path) build directive 
   macro. This is only available within test files.

In testing contexts, you have three options for creating the header 
file search path list used by Ceedling:

1. List all search paths within the `:paths` ↳ `:include` subsection 
   of your project file. This is the simplest and most common approach.
1. Create the search paths for each test file using calls to the 
  `TEST_INCLUDE_PATH(...)` build directive macro within each test file.
1. Blending the preceding options. In this approach the subsection
   within your project file acts as a common, base list of search 
   paths while the build directive macro allows the list to be 
   expanded upon for each test file. This method is especially helpful 
   for large and/or complex projects—especially in trimming down 
   problematically long compiler command lines.

## Conventions for Source Files & Binary Release Artifacts

Your binary release artifact results from the compilation and
linking of all source files Ceedling finds in the specified source
directories. At present only source files with a single (configurable)
extension are recognized. That is, `*.c` and `*.cc` files will not
both be recognized - only one or the other. See the configuration
options and defaults in the documentation for the `:extension`
sections of your configuration file (found later in this document).

## Conventions for Test Files & Executable Test Fixtures

Ceedling builds each individual test file with its accompanying
source file(s) into a single, monolithic test fixture executable.

### Test File Naming Convention

Ceedling recognizes test files by a naming convention — a (configurable)
prefix such as "`test_`" at the beginning of the file name with the same 
file extension as used by your C source files. See the configuration options
and defaults in the documentation for the `:project` and `:extension`
sections of your configuration file (elsewhere in this document).

Depending on your configuration options, Ceedling can recognize
a variety of test file naming patterns in your test search paths.
For example, `test_some_super_functionality.c`, `TestYourSourceFile.cc`,
or `testing_MyAwesomeCode.C` could each be valid test file
names. Note, however, that Ceedling can recognize only one test
file naming convention per project.

### Conventions for Source and Mock Files to Be Compiled & Linked

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
macro documentation elsewhere in this doc).

That was a lot of information and many clauses in a very few 
sentences; the commented example test file code that follows in a 
bit will make it clearer.

### Convention for Test Case Functions + Test Runner Generation

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

## The Magic of Dependency Tracking

Previous versions of Ceedling used features of Rake to offer
various kinds of smart rebuilds--that is, only regenerating files, 
recompiling code files, or relinking executables when changes within 
the project had occurred since the last build. Optional Ceedling 
features discovered “deep dependencies” such that, for example, a 
change in a header file several nested layers deep in `#include` 
statements would cause all the correct test executables to be 
updated and run.

These features have been temporarily disabled and/or removed for 
test suites and remain in limited form for release build while
Ceedling undergoes a major overhaul.

Please see the [Release Notes](ReleaseNotes.md).

### Notes on (Not So) Smart Rebuids

* New features that are a part of the Ceedling overhaul can 
  significantly speed up test suite execution and release builds 
  despite the present behavior of brute force running all build 
  steps. See the discussion of enabling multi-threaded builds in 
  later sections.

* When smart rebuilds return, they will further speed up builds as
  will other planned optimizations.

## Ceedling’s Build Output (Files, That Is)

Ceedling requires a top-level build directory for all the stuff
that it, the accompanying test tools, and your toolchain generate.
That build directory's location is configured in the top-level 
`:project` section of your configuration file (discussed later). There
can be a ton of generated files. By and large, you can live a full
and meaningful life knowing absolutely nothing at all about
the files and directories generated below the root build directory.

As noted already, it's good practice to add your top-level build
directory to source control but nothing generated beneath it.
You'll spare yourself headache if you let Ceedling delete and
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

## Build _Errors_ vs. Test _Failures_. Oh, and Exit Codes.

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

In its default configuration, Ceedling produces an exit code of `1`:

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
Add the following at the top-level of your project file (i.e. all the 
way to the left — not nested) to force Ceedling to finish a build 
with an exit code of 0 even upon test case failures.

```yaml
# Ceedling will terminate with happy `exit(0)` even if test cases fail
:graceful_fail: true
```

If you use the option for graceful failures in CI, you'll want to
rig up some kind of logging monitor that scans Ceedling's test
summary report sent to `$stdout` and/or a log file. Otherwise, you
could have a successful build but failing tests.

### Notes on Unity Test Executable Exit Codes

Ceedling works by collecting multiple Unity test executables together 
into a test suite ([more here](#anatomy-of-a-test-suite).

A Unity test executable's exit code is the number of failed tests. An
exit code of `0` means all tests passed while anything larger than zero
is the number of test failures.

Because of platform limitations on how big an exit code number can be
and because of the logical complexities of distinguishing test failure
counts from build errors or plugin problems, Ceedling conforms to a
much simpler exit code convention than Unity: `0` = 🙂 while `1` = ☹️.

<br/>

# Using Unity, CMock & CException

If you jumped ahead to this section but do not follow some of the 
lingo here, please jump back to an [earlier section for definitions
and helpful links][helpful-definitions].

[helpful-definitions]: #hold-on-back-up-ruby-rake-yaml-unity-cmock-cexception

## An overview of how Ceedling supports, well, its supporting frameworks

If you are using Ceedling for unit testing, this means you are using Unity,
the C testing framework. Unity is fully built-in and enabled for test builds.
It cannot be disabled.

If you want to use mocks in your test cases, then you'll need to configure CMock. 
CMock is fully supported by Ceedling, enabled by default, but generally requires
some set up for your project's needs.

If you are incorporating CException into your release artifact, you'll need to
both enable it and configure it. Enabling CException makes it available in 
both release builds and test builds.

This section provides a high-level view of how the various tools become
part of your builds and fit into Ceedling's configuration file. Ceedling's 
configuration file is discussed in detail in the next section.

See [Unity], [CMock], and [CException]'s project documentation for all 
your configuration options. Ceedling offers facilities for providing these
frameworks their compilation and configuration settings. Discussing 
these tools and all their options in detail is beyond the scope of Ceedling 
documentation.

## Unity Configuration

Unity is wholly compiled C code. As such, its configuration is entirely 
controlled by a variety of compilation symbols. These can be configured
in Ceedling's `:unity` project settings.

### Example Unity configurations

#### Itty bitty processor & toolchain with limited test execution options

```yaml
:unity:
  :defines:
    - UNITY_INT_WIDTH=16   # 16 bit processor without support for 32 bit instructions
    - UNITY_EXCLUDE_FLOAT  # No floating point unit
```

#### Great big gorilla processor that grunts and scratches

```yaml
:unity:
  :defines:
    - UNITY_SUPPORT_64                    # Big memory, big counters, big registers
    - UNITY_LINE_TYPE=\"unsigned int\"    # Apparently, we're writing lengthy test files,
    - UNITY_COUNTER_TYPE=\"unsigned int\" # and we've got a ton of test cases in those test files
    - UNITY_FLOAT_TYPE=\"double\"         # You betcha
```

#### Example Unity configuration header file

Sometimes, you may want to funnel all Unity configuration options into a 
header file rather than organize a lengthy `:unity` ↳ `:defines` list. Perhaps your
symbol definitions include characters needing escape sequences in YAML that are 
driving you bonkers.

```yaml
:unity:
  :defines:
    - UNITY_INCLUDE_CONFIG_H
```

```c
// unity_config.h
#ifndef UNITY_CONFIG_H
#define UNITY_CONFIG_H

#include "uart_output.h" // Helper library for your custom environment

#define UNITY_INT_WIDTH 16
#define UNITY_OUTPUT_START() uart_init(F_CPU, BAUD) // Helper function to init UART
#define UNITY_OUTPUT_CHAR(a) uart_putchar(a)        // Helper function to forward char via UART
#define UNITY_OUTPUT_COMPLETE() uart_complete()     // Helper function to inform that test has ended

#endif
```

### Routing Unity’s report output

Unity defaults to using `putchar()` from C's standard library to 
display test results.

For more exotic environments than a desktop with a terminal — e.g. 
running tests directly on a non-PC target — you have options.

For instance, you could create a routine that transmits a character via 
RS232 or USB. Once you have that routine, you can replace `putchar()` 
calls in Unity by overriding the function-like macro `UNITY_OUTPUT_CHAR`. 

Even though this override can also be defined in Ceedling YAML, most 
shell environments do not handle parentheses as command line arguments
very well. Consult your toolchain and shell documentation.

If redefining the function and macros breaks your command line 
compilation, all necessary options and functionality can be defined in 
`unity_config.h`. Unity will need the `UNITY_INCLUDE_CONFIG_H` symbol in the
`:unity` ↳ `:defines` list of your Ceedling project file (see example above).

## CMock Configuration

CMock is enabled in Ceedling by default. However, no part of it enters a
test build unless mock generation is triggered in your test files. 
Triggering mock generation is done by an `#include` convention. See the
section on [Ceedling conventions and behaviors][conventions] for more.

You are welcome to disable CMock in the `:project` block of your Ceedling
configuration file. This is typically only useful in special debugging
scenarios or for Ceedling development itself.

[conventions]: #important-conventions--behaviors

CMock is a mixture of Ruby and C code. CMock's Ruby components generate
C code for your unit tests. CMock's base C code is compiled and linked into 
a test executable in the same way that any C file is — including Unity, 
CException, and generated mock C code, for that matter. 

CMock's code generation can be configured using YAML similar to Ceedling 
itself. Ceedling's project file is something of a container for CMock's 
YAML configuration (Ceedling also uses CMock's configuration, though).

See the documentation for the top-level [`:cmock`][cmock-yaml-config] 
section within Ceedling's project file.

[cmock-yaml-config]: #cmock-configure-cmocks-code-generation--compilation

Like Unity and CException, CMock's C components are configured at 
compilation with symbols managed in your Ceedling project file's 
`:cmock` ↳ `:defines` section.

### Example CMock configurations

```yaml
:project:
  # Shown for completeness -- CMock enabled by default in Ceedling
  :use_mocks: TRUE

:cmock:
  :when_no_prototypes: :warn
  :enforce_strict_ordering: TRUE
  :defines:
    # Memory alignment (packing) on 16 bit boundaries
    - CMOCK_MEM_ALIGN=1
  :plugins:
    - :ignore
  :treat_as:
    uint8:    HEX8
    uint16:   HEX16
    uint32:   UINT32
    int8:     INT8
    bool:     UINT8
```

## CException Configuration

Like Unity, CException is wholly compiled C code. As such, its 
configuration is entirely controlled by a variety of `#define` symbols. 
These can be configured in Ceedling's `:cexception` ↳ `:defines` project 
settings.

Unlike Unity which is always available in test builds and CMock that 
defaults to available in test builds, CException must be enabled
if you wish to use it in your project.

### Example CException configurations

```yaml
:project:
  # Enable CException for both test and release builds
  :use_exceptions: TRUE

:cexception:
  :defines:
    # Possible exception codes of -127 to +127 
    - CEXCEPTION_T='signed char'

```

<br/>

# The Almighty Ceedling Project Configuration File (in Glorious YAML)

## Some YAML Learnin’

Please consult YAML documentation for the finer points of format
and to understand details of our YAML-based configuration file.

We recommend [Wikipedia's entry on YAML](http://en.wikipedia.org/wiki/Yaml)
for this. A few highlights from that reference page:

* YAML streams are encoded using the set of printable Unicode
  characters, either in UTF-8 or UTF-16.

* White space indentation is used to denote structure; however,
  tab characters are never allowed as indentation.

* Comments begin with the number sign (`#`), can start anywhere
  on a line, and continue until the end of the line unless enclosed
  by quotes.

* List members are denoted by a leading hyphen (`-`) with one member
  per line, or enclosed in square brackets (`[...]`) and separated
  by comma space (`, `).

* Hashes are represented using colon space (`: `) in the form
  `key: value`, either one per line or enclosed in curly braces
  (`{...}`) and separated by comma space (`, `).

* Strings (scalars) are ordinarily unquoted, but may be enclosed
  in double-quotes (`"`), or single-quotes (`'`).

* YAML requires that colons and commas used as list separators
  be followed by a space so that scalar values containing embedded
  punctuation can generally be represented without needing
  to be enclosed in quotes.

* Repeated nodes are initially denoted by an ampersand (`&`) and
  thereafter referenced with an asterisk (`*`). These are known as
  anchors and aliases in YAML speak.

## Notes on Project File Structure and Documentation That Follows

* Each of the following sections represent top-level entries
  in the YAML configuration file. Top-level means the named entries
  are furthest to the left in the hierarchical configuration file 
  (not at the literal top of the file).

* Unless explicitly specified in the configuration file by you, 
  Ceedling uses default values for settings.

* At minimum, these settings must be specified for a test suite:
  * `:project` ↳ `:build_root`
  * `:paths` ↳ `:source`
  * `:paths` ↳ `:test`
  * `:paths` ↳ `:include` and/or use of `TEST_INCLUDE_PATH(...)` 
    build directive macro within your test files

* At minimum, these settings must be specified for a release build:
  * `:project` ↳ `:build_root`
  * `:paths` ↳ `:source`

* As much as is possible, Ceedling validates your settings in
  properly formed YAML.

* Improperly formed YAML will cause a Ruby error when the YAML
  is parsed. This is usually accompanied by a complaint with
  line and column number pointing into the project file.

* Certain advanced features rely on `gcc` and `cpp` as preprocessing
  tools. In most Linux systems, these tools are already available.
  For Windows environments, we recommend the [MinGW] project
  (Minimalist GNU for Windows).

* Ceedling is primarily meant as a build tool to support automated
  unit testing. All the heavy lifting is involved there. Creating
  a simple binary release build artifact is quite trivial in
  comparison. Consequently, most default options and the construction
  of Ceedling itself is skewed towards supporting testing, though
  Ceedling can, of course, build your binary release artifact
  as well. Note that some complex binary release builds are beyond
  Ceedling's abilities. See the Ceedling plugin [subprojects] for
  extending release build abilities.

[MinGW]: http://www.mingw.org/

## Conventions of Ceedling-specific YAML

* Any second tier setting keys anywhere in YAML whose names end
  in `_path` or `_paths` are automagically processed like all
  Ceedling-specific paths in the YAML to have consistent directory
  separators (i.e. "/") and to take advantage of inline Ruby
  string expansion (see `:environment` setting below for further
  explanation of string expansion).

## Let’s Be Careful Out There

Ceedling performs validation of the values you set in your 
configuration file (this assumes your YAML is correct and will 
not fail format parsing, of course).

That said, validation is limited to only those settings Ceedling
uses and those that can be reasonably validated. Ceedling does
not limit what can exist within your configuration file. In this
way, you can take full advantage of YAML as well as add sections
and values for use in your own custom plugins (documented later).

The consequence of this is simple but important. A misspelled
configuration section or value name is unlikely to cause Ceedling 
any trouble. Ceedling will happily process that section
or value and simply use the properly spelled default maintained
internally - thus leading to unexpected behavior without warning.

## `:project`: Global project settings

**_Note:_** In future versions of Ceedling, test and release build 
settings presently organized beneath `:project` will be renamed and 
migrated to the `:test_build` and `:release_build` sections.

* `:build_root`

  Top level directory into which generated path structure and files are
  placed. Note: this is one of the handful of configuration values that
  must be set. The specified path can be absolute or relative to your
  working directory.

  **Default**: (none)

* `:use_mocks`

  Configures the build environment to make use of CMock. Note that if
  you do not use mocks, there's no harm in leaving this setting as its
  default value.

  **Default**: TRUE

* `:use_test_preprocessor`

  This option allows Ceedling to work with test files that contain
  conditional compilation statements (e.g. #ifdef) and header files you
  wish to mock that contain conditional preprocessor statements and/or
  macros.

  Ceedling and CMock are advanced tools with sophisticated parsers.
  However, they do not include entire C language preprocessors.
  Consequently, with this option enabled, Ceedling will use `gcc`'s
  preprocessing mode and the cpp preprocessor tool to strip down /
  expand test files and headers to their applicable content which can
  then be processed by Ceedling and CMock.

  With this option enabled, the `gcc` & `cpp` tools must exist in an
  accessible system search path and test runner files are always
  regenerated.

  **Default**: FALSE

* `:test_file_prefix`

  Ceedling collects test files by convention from within the test file
  search paths. The convention includes a unique name prefix and a file
  extension matching that of source files.

  Why not simply recognize all files in test directories as test files?
  By using the given convention, we have greater flexibility in what we
  do with C files in the test directories.

  **Default**: "test_"

* `:options_paths`

  Just as you may have various build configurations for your source
  codebase, you may need variations of your project configuration.

  By specifying options paths, Ceedling will search for other project
  YAML files, make command line tasks available (ceedling options:variation
  for a variation.yml file), and merge the project configuration of
  these option files in with the main project file at runtime. See
  advanced topics.

  Note these Rake tasks at the command line - like verbosity or logging
  control - must come before the test or release task they are meant to
  modify.

  **Default**: `[]` (empty)

* `:release_build`

  When enabled, a release Rake task is exposed. This configuration
  option requires a corresponding release compiler and linker to be
  defined (`gcc` is used as the default).

  Ceedling is primarily concerned with facilitating the complicated 
  mechanics of automating unit tests. The same mechanisms are easily 
  capable of building a final release binary artifact (i.e. non test 
  code — the thing that is your final working software that you execute 
  on target hardware). That said, if you have complicated release 
  builds, you should consider a traditional build tool for these.
  Ceedling shines at executing test suites.

  More release configuration options are available in the `:release_build`
  section.

  **Default**: FALSE

* `:compile_threads`

  A value greater than one enables parallelized build steps. Ceedling
  creates a number of threads up to `:compile_threads` for build steps.
  These build steps execute batched operations including but not 
  limited to mock generation, code compilation, and running test 
  executables.

  Particularly if your build system includes multiple cores, overall 
  build time will drop considerably as compared to running a build with 
  a single thread.

  Tuning the number of threads for peak performance is an art more 
  than a science. A special value of `:auto` instructs Ceedling to 
  query the host system's number of virtual cores. To this value it 
  adds a constant of 4. This is often a good value sufficient to "max
  out" available resources without overloading available resources.

  `:compile_threads` is used for all release build steps and all test
  suite build steps except for running the test executables that make
  up a test suite. See next section for more.

  **Default**: 1

* `:test_threads`

  The behavior of and values for `:test_threads` are identical to 
  `:compile_threads` with one exception.

  `test_threads:` specifically controls the number of threads used to
  run the test executables comprising a test suite.

  Why the distinction from `:compile_threads`? Some test suite builds 
  rely not on native executables but simulators running cross-compiled 
  code. Some simulators are limited to running only a single instance at 
  a time. Thus, with this and the previous setting, it becomes possible 
  to parallelize nearly all of a test suite build while still respecting
  the limits of certain simulators depended upon by test executables.

  **Default**: 1

### Example `:project` YAML blurb

```yaml
:project:
  :build_root: project_awesome/build
  :use_exceptions: FALSE
  :use_test_preprocessor: TRUE
  :options_paths:
    - project/options
    - external/shared/options
  :release_build: TRUE
  :compile_threads: :auto
```

* `:use_backtrace`
  When a test file runs into a **Segmentation Fault**, the test executable 
  immediately crashes and further details aren't collected. By default, Ceedling
  reports a single failure for the entire file, specifying that it segfaulted. 
  If you are running `gcc` or Clang (LLVM), then there is an option to get more
  detail!

  Set `:use_backtrace` to `true` and a segfault will trigger Ceedling to 
  collect backtrace data from test runners. It will then run each test in the
  faulted test file individually, collecting the pass/fail results as normal, and
  providing further default on the test that actually faulted.

  **Default**: FALSE

  **Note:**

    The configuration option requires that it be combined with the following:
    
    ``` yaml
    :test_runner:
        :cmdline_args: true
    ```

    If a test segfaults when `cmdline_args` has be set to `true`, the debugger will execute 
    each test independently in order to determine which test(s) cause the segfault. Other 
    tests will be reported as normal.

    When enabled, .gcno and .gcda files will be generated automatically and the section of the 
    code under test case causing the segmetation fault will be omitted from Coverage Report.

    The default debugger (gdb)[https://www.sourceware.org/gdb/] can be switched to other
    debug engines via setting a new configuration under the tool node in project.yml. 
    By default, this tool is set as follows:

    ```yaml
   :tools:
     :backtrace_reporter:
       :executable: gdb
       :arguments:
         - -q
         - --eval-command run
         - --eval-command backtrace
         - --batch
         - --args
    ```
    
    It is important that the debugging tool should be run as a background task, and with the
    option to pass additional arguments to the test executable.

## `:test_build` Configuring a test build

**_Note:_** In future versions of Ceedling, test-related settings presently 
organized beneath `:project` will be renamed and migrated to this section.

* `:use_assembly`

  This option causes Ceedling to enable an assembler tool and collect a
  list of assembly file sources for use in a test suite build.

  The default assembler is the GNU tool `as`; it may be overridden in 
  the `:tools` section.

  In order to inject assembly code into the build of a test executable,
  two conditions must be true:

  1. The assembly files must be visible to Ceedling by way of `:paths` and
  `:extension` settings for assembly files.
  1. Ceedling must be told into which test executable build to insert a
  given assembly file. The easiest way to do so is with the 
  `TEST_SOURCE_FILE()` build directive macro (documented in a later section).

  **Default**: FALSE

### Example `:test_build` YAML blurb

```yaml
:test_build:
  :use_assembly: TRUE
```

## `:release_build` Configuring a release build

**_Note:_** In future versions of Ceedling, release build-related settings 
presently organized beneath `:project` will be renamed and migrated to 
this section.

* `:output`

  The name of your release build binary artifact to be found in <build
  path>/artifacts/release. Ceedling sets the default artifact file
  extension to that as is explicitly specified in the `:extension`
  section or as is system specific otherwise.

  **Default**: `project.exe` or `project.out`

* `:use_assembly`

  This option causes Ceedling to enable an assembler tool and add any 
  assembly code present in the project to the release artifact's build.

  The default assembler is the GNU tool `as`; it may be overridden 
  in the `:tools` section.

  The assembly files must be visible to Ceedling by way of `:paths` and
  `:extension` settings for assembly files.

  **Default**: FALSE

* `:artifacts`

  By default, Ceedling copies to the <build path>/artifacts/release
  directory the output of the release linker and (optionally) a map
  file. Many toolchains produce other important output files as well.
  Adding a file path to this list will cause Ceedling to copy that file
  to the artifacts directory.

  The artifacts directory is helpful for organizing important build 
  output files and provides a central place for tools such as Continuous 
  Integration servers to point to build output. Selectively copying 
  files prevents incidental build cruft from needlessly appearing in the 
  artifacts directory.

  Note that inline Ruby string replacement is available in the artifacts 
  paths (see discussion in the `:environment` section).

  **Default**: `[]` (empty)

### Example `:release_build` YAML blurb

```yaml
:release_build:
  :output: top_secret.bin
  :use_assembly: TRUE
  :artifacts:
    - build/release/out/c/top_secret.s19
```

## Project `:paths` configuration

**Paths for build tools and building file collections**

Ceedling relies on various path and file collections to do its work. File
collections are automagically assembled from paths, matching globs / wildcards,
and file extensions (see project configuration `:extension`).

Entries in `:paths` help create directory-based bulk file collections. The
`:files` configuration section is available for filepath-oriented tailoring of
these buk file collections.

Entries in `:paths` ↳ `:include` also specify search paths for header files.

All of the configuration subsections that follow default to empty lists. In
YAML, list items can be comma separated within brackets or organized per line
with a dash. An empty list can only be denoted as `[]`. Typically, you will see
Ceedling project files use lists broken up per line.

```yaml
:paths:
  :support: []    # Empty list (internal default)
  :source:
    - files/code  # Typical list format

```

Examples that illustrate the many `:paths` entry features follow all
the various path-related documentation sections.

* <h3><code>:paths</code> ↳ <code>:test</code></h3>

  All C files containing unit test code. Note: this is one of the
  handful of configuration values that must be set for a test suite.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:source</code></h3>

  All C files containing release code (code to be tested)

  Note: this is one of the handful of configuration values that must 
  be set for either a release build or test suite.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:support</code></h3>

  Any C files you might need to aid your unit testing. For example, on
  occasion, you may need to create a header file containing a subset of
  function signatures matching those elsewhere in your code (e.g. a
  subset of your OS functions, a portion of a library API, etc.). Why?
  To provide finer grained control over mock function substitution or
  limiting the size of the generated mocks.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:include</code></h3>

  See these two important discussions to fully understand your options
  for header file search paths:

   * [Configuring Your Header File Search Paths][header-file-search-paths]
   * [`TEST_INCLUDE_PATH(...)` build directive macro][test-include-path-macro]

  [header-file-search-paths]: #configuring-your-header-file-search-paths
  [test-include-path-macro]: #test_include_path

  This set of paths specifies the locations of your header files. If 
  your header files are intermixed with source files, you must duplicate 
  some or all of your `:paths` ↳ `:source` entries here.

  In its simplest use, your include paths list can be exhaustive.
  That is, you list all path locations where your project's header files
  reside in this configuration list.

  However, if you have a complex project or many, many include paths that 
  create problematically long search paths at the compilation command 
  line, you may treat your `:paths` ↳ `:include` list as a base, common 
  list. Having established that base list, you can then extend it on a 
  test-by-test basis with use of the `TEST_INCLUDE_PATH(...)` build 
  directive macro in your test files.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:test_toolchain_include</code></h3>

  System header files needed by the test toolchain - should your
  compiler be unable to find them, finds the wrong system include search
  path, or you need a creative solution to a tricky technical problem.

  Note that if you configure your own toolchain in the `:tools` section,
  this search path is largely meaningless to you. However, this is a
  convenient way to control the system include path should you rely on
  the default [GCC] tools.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:release_toolchain_include</code></h3>

  Same as preceding albeit related to the release toolchain.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:libraries</code></h3>

  Library search paths. See `:libraries` section.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:&lt;custom&gt;</code></h3>

  Any paths you specify for custom list. List is available to tool
  configurations and/or plugins. Note a distinction – the preceding names
  are recognized internally to Ceedling and the path lists are used to
  build collections of files contained in those paths. A custom list is
  just that - a custom list of paths.

### `:paths` configuration options & notes

1. A path can be absolute (fully qualified) or relative.
1. A path can include a glob matcher (more on this below).
1. A path can use inline Ruby string replacement (see `:environment` section 
   for more).
1. Subtractive paths are possible and useful. See the documentation below.
1. Path order beneath a subsection (e.g. `:paths` ↳ `:include`) is preserved 
   when the list is iterated internally or passed to a tool.

### `:paths` Globs

Globs are effectively fancy wildcards. They are not as capable as full regular
expressions but are easier to use. Various OSs and programming languages
implement them differently.

For a quick overview, see this [tutorial][globs-tutorial].

Ceedling supports globs so you can specify patterns of directories without the
need to list each and every required path.

Ceedling `:paths` globs operate similarlry to [Ruby globs][ruby-globs] except
that they are limited to matching directories within `:paths` entries and not
also files. In addition, Ceedling adds a useful convention with certain uses of
the `*` and `**` operators.

Glob operators include the following: `*`, `**`, `?`, `[-]`, `{,}`.

* `*`
   * When used within a character string, `*` is simply a standard wildcard.
   * When used after a path separator, `/*` matches all subdirectories of depth 1
     below the parent path, not including the parent path.
* `**`: All subdirectories recursively discovered below the parent path, not
  including the parent path. This pattern only makes sense after a path
  separator `/**`.
* `?`: Single alphanumeric character wildcard.
* `[x-y]`: Single alphanumeric character as found in the specified range.
* `{x, y, ...}`: Matching any of the comma-separated patterns. Two or more 
  patterns may be listed within the brackets. Patterns may be specific 
  character sequences or other glob operators.

Special conventions:

* If a globified path ends with `/*` or `/**`, the resulting list of directories
  also includes the parent directory.

See the example `:paths` YAML blurb section.

[globs-tutotrial]: http://ruby.about.com/od/beginningruby/a/dir2.htm
[ruby-globs]: https://ruby-doc.org/core-3.0.0/Dir.html#method-c-glob

### Subtractive `:paths` entries

Globs are super duper helpful when you have many paths to list. But, what if a
single glob gets you 20 nested paths, but you actually want to exclude 2 of
those paths?

Must you revert to listing all 18 paths individually? No, my friend, we've got
you. Behold, subtractive paths.

Put simply, with an optional preceding decorator `-:`, you can instruct Ceedling
to remove certain directory paths from a collection after it builds that
collection.

By default, paths are additive. For pretty alignment in your YAML, you may also
use `+:`, but strictly speaking, it's not necessary.

Subtractive paths may be simple paths or globs just like any other path entry.

See examples below.

### Example `:paths` YAML blurbs

_Note:_ Ceedling standardizes paths for you. Internally, all paths use forward
 slash `/` path separators (including on Windows), and Ceedling cleans up
 trailing path separators to be consistent internally.

#### Simple `:paths` entries

```yaml
:paths:
  # All <dirs>/*.<source extension> => test/release compilation input
  :source:
    - project/src/            # Resulting source list has just two relative directory paths
    - project/aux             # (Traversal goes no deeper than these simple paths)

  # All <dirs> => compilation search paths + mock search paths
  :include:                   # All <dirs> => compilation input
    - project/src/inc         # Include paths are subdirectory of src/
    - /usr/local/include/foo  # Header files for a prebuilt library at fully qualified path

  # All <dirs>/<test prefix>*.<source extension> => test compilation input + test suite executables
  :test:                
    - ../tests                # Tests have parent directory above working directory
```

#### Common `:paths` globs with subtractive path entries

```yaml
:paths:
  :source:              
    - +:project/src/**    # Recursive glob yields all subdirectories of any depth plus src/
    - -:project/src/exp   # Exclude experimental code in exp/ from release or test builds
                          # `+:` is decoration for pretty alignment; only `-:` changes a list

  :include:
    - +:project/src/**/inc   # Include every subdirectory inc/ beneath src/
    - -:project/src/exp/inc  # Remove header files subdirectory for experimental code
```

#### Advanced `:paths` entries with globs and string expansion

```yaml
:paths:
  :test:                             
    - test/**/f???             # Every 4 character “f-series" subdirectory beneath test/

  :my_things:                  # Custom path list
    - "#{PROJECT_ROOT}/other"  # Inline Ruby string expansion using Ceedling global constant
```

```yaml
:paths:
  :test:                             
    - test/{foo,b*,xyz}  # Path list will include test/foo/, test/xyz/, and any subdirectories 
                         # beneath test/ beginning with 'b', including just test/b/
```

Globs and inline Ruby string expansion can require trial and error to arrive at
your intended results. Ceedling provides as much validation of paths as is 
practical.

Use the `ceedling paths:*` and `ceedling files:*` command line tasks —
documented in a preceding section — to verify your settings. (Here `*` is
shorthand for `test`, `source`, `include`, etc. Confusing? Sorry.)

## `:files` Modify file collections

**File listings for tailoring file collections**

Ceedling relies on file collections to do its work. These file collections are
automagically assembled from paths, matching globs / wildcards, and file
extensions (see project configuration `:extension`).

Entries in `:files` accomplish filepath-oriented tailoring of the bulk file
collections created from `:paths` directory listings and filename pattern
matching.

On occasion you may need to remove from or add individual files to Ceedling's
file collections.

The path grammar documented in the `:paths` configuration section largely
applies to `:files` path entries - albeit with regard to filepaths and not
directory paths. The `:files` grammar and YAML examples are documented below.

* <h3><code>:files</code> ↳ <code>:test</code></h3>

  Modify the collection of unit test C files.
  
  **Default**: `[]` (empty)

* <h3><code>:files</code> ↳ <code>:source</code></h3>

  Modify the collection of all source files used in unit test builds and release builds.
  
  **Default**: `[]` (empty)

* <h3><code>:files</code> ↳ <code>:assembly</code></h3>

  Modify the (optional) collection of assembly files used in release builds.
  
  **Default**: `[]` (empty)

* <h3><code>:files</code> ↳ <code>:include</code></h3>

  Modify the collection of all source header files used in unit test builds (e.g. for mocking) and release builds.
  
  **Default**: `[]` (empty)

* <h3><code>:files</code> ↳ <code>:support</code></h3>

  Modify the collection of supporting C files available to unit tests builds.
  
  **Default**: `[]` (empty)

* <h3><code>:files</code> ↳ <code>:libraries</code></h3>

  Add a collection of library paths to be included when linking.
  
  **Default**: `[]` (empty)

### `:files` configuration options & notes

1. A path can be absolute (fully qualified) or relative.
1. A path can include a glob matcher (more on this below).
1. A path can use inline Ruby string replacement (see `:environment` section 
   for more).
1. Subtractive paths prepended with a `-:` decorator are possible and useful. 
   See the documentation below.

### `:files` Globs

Globs are effectively fancy wildcards. They are not as capable as full regular
expressions but are easier to use. Various OSs and programming languages
implement them differently.

For a quick overview, see this [tutorial][globs-tutorial].

Ceedling supports globs so you can specify patterns of files as well as simple,
ordinary filepaths.

Ceedling `:files` globs operate identically to [Ruby globs][ruby-globs] except
that they ignore directory paths. Only filepaths are recognized.

Glob operators include the following: `*`, `**`, `?`, `[-]`, `{,}`.

* `*`
   * When used within a character string, `*` is simply a standard wildcard.
   * When used after a path separator, `/*` matches all subdirectories of depth
     1 below the parent path, not including the parent path.
* `**`: All subdirectories recursively discovered below the parent path, not
  including the parent path. This pattern only makes sense after a path
  separator `/**`.
* `?`: Single alphanumeric character wildcard.
* `[x-y]`: Single alphanumeric character as found in the specified range.
* `{x, y, ...}`: Matching any of the comma-separated patterns. Two or more
  patterns may be listed within the brackets. Patterns may be specific
  character sequences or other glob operators.

### Subtractive `:files` entries

Tailoring a file collection includes adding to it but also subtracting from it.

Put simply, with an optional preceding decorator `-:`, you can instruct Ceedling
to remove certain file paths from a collection after it builds that
collection.

By default, paths are additive. For pretty alignment in your YAML, you may also
use `+:`, but strictly speaking, it's not necessary.

Subtractive paths may be simple paths or globs just like any other path entry.

See examples below.

### Example `:files` YAML blurbs

#### Simple `:files` tailoring

```yaml
:paths:
  # All <dirs>/*.<source extension> => test/release compilation input
  :source:
    - src/**

:files:
  :source:
    - +:callbacks/serial_comm.c  # Add source code outside src/
    - -:src/board/atm134.c       # Remove board code
```

#### Advanced `:files` tailoring

```yaml
:paths:
  # All <dirs>/<test prefix>*.<source extension> => test compilation input + test suite executables
  :test:
     - test/**

:files:
  :test:
    # Remove every test file anywhere beneath test/ whose name ends with 'Model'. 
    # String replacement inserts a global constant that is the file extension for 
    # a C file. This is an anchor for the end of the filename and automaticlly 
    # uses file extension settings.
    - "-:test/**/*Model#{EXTENSION_SOURCE}"

    # Remove test files at depth 1 beneath test/ with 'analog' anywhere in their names.
    - -:test/*{A,a}nalog*

    # Remove test files at depth 1 beneath test/ that are of an “F series”
    # test collection FAxxxx, FBxxxx, and FCxxxx where 'x' is any character.
    - -:test/F[A-C]????
```

## `:environment:` Insert environment variables into shells running tools

Ceedling creates environment variables from any key / value pairs in the 
environment section. Keys become an environment variable name in uppercase. The
values are strings assigned to those environment variables. These value strings 
are either simple string values in YAML or the concatenation of a YAML array
of strings.

Ceedling is able to execute inline Ruby string substitution code to set 
environment variables. This evaluation occurs when the project file is first 
processed for any environment pair's value string including the Ruby string 
substitution pattern `#{…}`. Note that environment value entries including this
pattern should always be enclosed in quotes. YAML defaults to processing 
unquoted text as a string; quoting text is optional. If an environment entry's 
value string includes the Ruby string substitution pattern, YAML will interpret 
the string as a YAML comment (because of the `#`). Enclosing each environment 
entry value string in quotes is a safe practice.

`:environment` entries are processed in the configured order (later entries 
can reference earlier entries).

### Special case: `PATH` handling

In the specific case of specifying an environment key named `:path`, an array 
of string values will be concatenated with the appropriate platform-specific 
path separation character (i.e. `:` on Unix-variants, `;` on Windows).

All other instances of environment keys assigned a value of a YAML array use 
simple concatenation.

### Example `:environment` YAML blurb

```yaml
:environment:
  - :license_server: gizmo.intranet        # LICENSE_SERVER set with value "gizmo.intranet"
  - :license: "#{`license.exe`}"           # LICENSE set to string generated from shelling out to
                                           # xecute license.exe; note use of enclosing quotes to
                                           # prevent a YAML comment.

  - :path:                                 # Concatenated with path separator (see special case above)
     - Tools/gizmo/bin                     # Prepend existing PATH with gizmo path
     - "#{ENV['PATH']}"                    # Pattern #{…} triggers ruby evaluation string substitution
                                           # Note: value string must be quoted because of '#' to 
                                           # prevent a YAML comment.

  - :logfile: system/logs/thingamabob.log  #LOGFILE set with path for a log file
```

## `:extension` Filename extensions used to collect lists of files searched in `:paths`

Ceedling uses path lists and wildcard matching against filename extensions to collect file lists.

* `:header`:

  C header files

  **Default**: .h

* `:source`:

  C code files (whether source or test files)

  **Default**: .c

* `:assembly`:

  Assembly files (contents wholly assembler instructions)

  **Default**: .s

* `:object`:

  Resulting binary output of C code compiler (and assembler)

  **Default**: .o

* `:executable`:

  Binary executable to be loaded and executed upon target hardware

  **Default**: .exe or .out (Win or Linux)

* `:testpass`:

  Test results file (not likely to ever need a redefined value)

  **Default**: .pass

* `:testfail`:

  Test results file (not likely to ever need a redefined value)

  **Default**: .fail

* `:dependencies`:

  File containing make-style dependency rules created by the `gcc` preprocessor

  **Default**: .d

### Example `:extension` YAML blurb

```yaml
:extension:
  :source: .cc
  :executable: .bin
```

## `:defines` Command line symbols used in compilation

Ceedling's internal, default compiler tool configurations (see later `:tools` section) 
execute compilation of test and source C files.

These default tool configurations are a one-size-fits-all approach. If you need to add to
the command line symbols for individual tests or a release build, the `:defines` section 
allows you to easily do so.

Particularly in testing, symbol definitions in the compilation command line are often needed:

1. You may wish to control aspects of your test suite. Conditional compilation statements
   can control which test cases execute in which circumstances. (Preprocessing must be 
   enabled, `:project` ↳ `:use_test_preprocessor`.)

1. Testing means isolating the source code under test. This can leave certain symbols 
   unset when source files are compiled in isolation. Adding symbol definitions in your
   Ceedling project file for such cases is one way to meet this need.

Entries in `:defines` modify the command lines for compilers used at build time. In the
default case, symbols listed beneath `:defines` become `-D<symbol>` arguments.

### `:defines` verification (Ceedling does none)

Ceedling does no verification of your configured `:define` symbols.

Unity, CMock, and CException conditional compilation statements, your toolchain's 
preprocessor, and/or your toolchain's compiler will complain appropriately if your 
specified symbols are incorrect, incomplete, or incompatible.

### `:defines` organization: Contexts and Matchers

The basic layout of `:defines` involves the concept of contexts.

General case:
```yaml
:defines:
  :<context>:
    - <symbol>
    - ...
```

Advanced matching for test build handling only:
```yaml
:defines:
  :test:
    :<matcher>
      - <symbol>
      - ...
```

A context is the build context you want to modify — `:test` or `:release`. Plugins
can also hook into `:defines` with their own context.

You specify the symbols you want to add to a build step beneath a `:<context>`. In many 
cases this is a simple YAML list of strings that will become symbols defined in a 
compiler's command line.

Specifically in the `:test` context you also have the option to create test file matchers 
that create symbol definitions for some subset of your test build. Note that file 
matchers and the simpler list format cannot be mixed for `:defines` ↳ `:test`.

* <h3><code>:defines</code> ↳ <code>:release</code></h3>

  This project configuration entry adds the items of a simple YAML list as symbols to 
  the compilation of every C file in a release build.
  
  **Default**: `[]` (empty)

* <h3><code>:defines</code> ↳ <code>:preprocess</code></h3>

  This project configuration entry adds the specified items as symbols to any needed 
  preprocessing of components in a test executable's build. (Preprocessing must be enabled, 
  `:project` ↳ `:use_test_preprocessor`.)
  
  Preprocessing here refers to handling macros, conditional includes, etc. in header files 
  that are mocked and in complex test files before runners are generated from them.
  
  Symbols may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus symbol list. Both are documented below.
  
  _Note:_ Left unspecified, `:preprocess` symbols default to be identical to `:test` 
  symbols. Override this behavior by adding `:defines` ↳ `:preprocess` flags. If you want 
  no additional flags for preprocessing regardless of `test` symbols, simply specify an 
  empty list `[]`.
  
  **Default**: `[]` (empty)

* <h3><code>:defines</code> ↳ <code>:test</code></h3>

  This project configuration entry adds the specified items as symbols to compilation of C 
  components in a test executable's build.
  
  Symbols may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus symbol list. Both are documented below.
  
  **Default**: `[]` (empty)

* <h3><code>:defines</code> ↳ <code>:&lt;plugin context&gt;</code></h3>

  Some advanced plugins make use of build contexts as well. For instance, the Ceedling 
  Gcov plugin uses a context of `:gcov`, surprisingly enough. For any plugins with tools
  that take advantage of Ceedling's internal mechanisms, you can add to those tools'
  compilation symbols in the same manner as the built-in contexts.

### `:defines` options

* `:use_test_definition`:

  If enabled, add a symbol to test compilation derived from the test file name. The 
  resulting symbol is a sanitized, uppercase, ASCII version of the test file name.
  Any non ASCII characters (e.g. Unicode) are replaced by underscores as are any 
  non-alphanumeric characters. Underscores and dashes are preserved. The symbol name
  is wrapped in underscores unless they already exist in the leading and trailing
  positions. Example: _test_123abc-xyz😵.c_ ➡️ `_TEST_123ABC-XYZ_`.

  **Default**: False

### Simple `:defines` configuration

A simple and common need is configuring conditionally compiled features in a code base.
The following example illustrates using simple YAML lists for symbol definitions at 
compile time.

```yaml
:defines:
  :test:
    - FEATURE_X=ON
    - PRODUCT_CONFIG_C
  :release:
    - FEATURE_X=ON
    - PRODUCT_CONFIG_C
```

Given the YAML blurb above, the two symbols will be defined in the compilation command 
lines for all C files in a test suite build or release build.

### Advanced `:defines` per-test matchers

Ceedling treats each test executable as a mini project. As a reminder, each test file,
together with all C sources and frameworks, becomes an individual test executable of
the same name.

_In the `:test` context only_, symbols may be defined for only those test executable 
builds that match file name criteria. Matchers match on test file names only, and the 
specified symbols are added to the build step for all files that are components of 
matched test executables.

In short, for instance, this means your compilation of _TestA_ can have different 
symbols than compilation of _TestB_. Those symbols will be applied to every C file 
that is compiled as part those individual test executable builds. Thus, in fact, with 
separate test files unit testing the same source C file, you may exercise different 
conditional compilations of the same source. See the example in the section below.

#### `:defines` per-test matcher examples with YAML

Before detailing matcher capabilities and limits, here are examples to illustrate the
basic ideas of test file name matching.

This example builds on the previous simple symbol list example. The imagined scenario
is that of unit testing the same single source C file with different product features 
enabled.

```yaml
# Imagine three test files all testing aspects of a single source file Comms.c with 
# different features enabled via conditional compilation.
:defines:
  :test:
    # Tests for FeatureX configuration
    :CommsFeatureX:      # Matches a C test file name including 'CommsFeatureX'
      - FEATURE_X=ON
      - FEATURE_Z=OFF
      - PRODUCT_CONFIG_C
    # Tests for FeatureZ configuration
    :CommsFeatureZ:      # Matches a C test file name including 'CommsFeatureZ'
      - FEATURE_X=OFF
      - FEATURE_Z=ON
      - PRODUCT_CONFIG_C
    # Tests of base functionality
    :CommsBase:          # Matches a C test file name including 'CommsBase'
      - FEATURE_X=OFF
      - FEATURE_Z=OFF
      - PRODUCT_BASE
```

This example illustrates each of the test file name matcher types.

```yaml
:defines:
  :test:
    :*:                       #  Wildcard: Add '-DA' for compilation all files for all tests
      - A                  
    :Model:                   # Substring: Add '-DCHOO' for compilation of all files of any test with 'Model' in its name
      - CHOO
    :/M(ain|odel)/:           #     Regex: Add '-DBLESS_YOU' for all files of any test with 'Main' or 'Model' in its name
      - BLESS_YOU
    :Comms*Model:             #  Wildcard: Add '-DTHANKS' for all files of any test that have zero or more characters
      - THANKS                #            between 'Comms' and 'Model'
```

#### Using `:defines` per-test matchers

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

Symbols by matcher are cumulative. This means the symbols from more than one
matcher can be applied to compilation for the components of any one test
executable.

Referencing the example above, here are the extra compilation symbols for a
handful of test executables:

* _test_Something_: `-DA`
* _test_Main_: `-DA -DBLESS_YOU`
* _test_Model_: `-DA -DCHOO -DBLESS_YOU`
* _test_CommsSerialModel_: `-DA -DCHOO -DBLESS_YOU -DTHANKS`

The simple `:defines` list format remains available for the `:test` context. The
YAML blurb below is equivalent to the plain wildcard matcher above. Of course,
this format is limited in that it applies symbols to the compilation of all C
files for all test executables.

```yaml
:defines:
  :test:
    - A   # Equivalent to wildcard '*' test file matching
```

#### Distinguishing similar or identical filenames with `:defines` per-test matchers

You may find yourself needing to distinguish test files with the same name or test 
files with names whose base naming is identical.

Of course, identical test filenames have a natural distinguishing feature in their 
containing directory paths. Files of the same name can only exist in different
directories. As such, your matching must include the path.

```yaml
:defines:
  :test:
    :hardware/test_startup:  # Match any test names beginning with 'test_startup' in hardware/ directory
      - A                  
    :network/test_startup:   # Match any test names beginning with 'test_startup' in network/ directory
      - B
```

It's common in C file naming to use the same base name for multiple files. Given the
following example list, care must be given to matcher construction to single out
test_comm_startup.c.

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

#### Using YAML anchors & aliases for complex testing scenarios with `:defines`

See the short but helpful article on [YAML anchors & aliases][yaml-anchors-aliases] to 
understand these features of YAML.

Particularly in testing complex projects, per-test file matching may only get you so
far in meeting your symbol definition needs. For instance, you may need to use the 
same symbols across many test files, but no convenient name matching scheme works. 
Advanced YAML features can help you copy the same symbols into multiple `:defines` 
test file matchers.

The following advanced example illustrates how to create a set of file matches for 
test preprocessing that are identical to test compilation with one addition.

In brief, this example uses YAML to copy all the `:test` file matchers into 
`:preprocess` and add an additional symbol to the list for all test file
wildcard matching.

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

## `:libraries`

Ceedling allows you to pull in specific libraries for release and test builds with a 
few levels of support.

* <h3><code>:libraries</code> ↳ <code>:test</code></h3>

  Libraries that should be injected into your test builds when linking occurs.
  
  These can be specified as naked library names or with relative paths if search paths
  are specified with `:paths` ↳ `:libraries`. Otherwise, absolute paths may be used
  here.
  
  These library files **must** exist when tests build.
  
  **Default**: `[]` (empty)

* <h3><code>:libraries</code> ↳ <code>:release</code></h3>

  Libraries that should be injected into your release build when linking occurs.
  
  These can be specified as naked library names or with relative paths if search paths
  are specified with `:paths` ↳ `:libraries`. Otherwise, absolute paths may be used
  here.
  
  These library files **must** exist when the release build occurs **unless** you 
  are using the _subprojects_ plugin. In that case, the plugin will attempt to build 
  the needed library for you as a dependency.
  
  **Default**: `[]` (empty)

* <h3><code>:libraries</code> ↳ <code>:system</code></h3>

  Libraries listed here will be injected into releases and tests.
  
  These libraries are assumed to be findable by the configured linker tool, should need
  no path help, and can be specified by common linker shorthand for libraries.
  
  For example, specifying `m` will include the math library per the GCC convention. The
  file itself on a Unix-like system will be `libm` and the `gcc` command line argument 
  will be `-lm`.
  
  **Default**: `[]` (empty)

### `:libraries` options

* `:flag`:

  Command line argument format for specifying a library.

  **Default**: `-l${1}` (GCC format)

* `:path_flag`:

  Command line argument format for adding a library search path.

  Library search paths may be added to your project with `:paths` ↳ `:libraries`.

  **Default**: `-L "${1}”` (GCC format)

### `:libraries` example with YAML blurb

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

### `:libraries` notes

* If you've specified your own link step, you are going to want to add `${4}` to your 
  argument list in the position where library files should be added to the command line. 
  For `gcc`, this is often at the very end. Other tools may vary. See the `:tools` 
  section for more.

## `:flags` Configure preprocessing, compilation & linking command line flags

Ceedling's internal, default tool configurations (see later `:tools` section) execute 
compilation and linking of test and source files among other needs.

These default tool configurations are a one-size-fits-all approach. If you need to add to
the command line flags for individual tests or a release build, the `:flags` section allows
you to easily do so.

Entries in `:flags` modify the command lines for tools used at build time.

### Flags organization: Contexts, Operations, and Matchers

The basic layout of `:flags` involves the concepts of contexts and operations.

General case:
```yaml
:flags:
  :<context>:
    :<operation>:
      - <flag>
      - ...
```

Advanced matching for test build handling only:
```yaml
:flags:
  :test:
    :<operation>:
      :<matcher>
        - <flag>
        - ...
```

A context is the build context you want to modify — `:test` or `:release`. Plugins can
also hook into `:flags` with their own context.

An operation is the build step you wish to modify — `:preprocess`, `:compile`, `:assemble`, 
or `:link`.

* The `:preprocess` operation is only available in the `:test` context.
* The `:assemble` operation is only available within the `:test` or `:release` contexts if 
  assembly support has been enabled in `:test_build` or `:release_build`, respectively, and
  assembly files are a part of the project.

You specify the flags you want to add to a build step beneath `:<context>` ↳ `:<operation>`.
In many cases this is a simple YAML list of strings that will become flags in a tool's 
command line.

Specifically in the `:test` context you also have the option to create test file matchers 
that apply flags to some subset of your test build. Note that file matchers and the simpler
flags list format cannot be mixed for `:flags` ↳ `:test`.

* <h3><code>:flags</code> ↳ <code>:release</code> ↳ <code>:compile</code></h3>

  This project configuration entry adds the items of a simple YAML list as flags to 
  compilation of every C file in a release build.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:release</code> ↳ <code>:link</code></h3>

  This project configuration entry adds the items of a simple YAML list as flags to 
  the link step of a release build artifact.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:test</code> ↳ <code>:preprocess</code></h3>

  This project configuration entry adds the specified items as flags to any needed 
  preprocessing of components in a test executable's build. (Preprocessing must be enabled, 
  `:project` ↳ `:use_test_preprocessor`.)
  
  Preprocessing here refers to handling macros, conditional includes, etc. in header files 
  that are mocked and in complex test files before runners are generated from them.
  
  Flags may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus flag list. Both are documented below.
  
  _Note:_ Left unspecified, `:preprocess` flags default to behaving identically to `:compile` 
  flags. Override this behavior by adding `:test` ↳ `:preprocess` flags. If you want no 
  additional flags for preprocessing regardless of test compilation flags, simply specify 
  an empty list `[]`.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:test</code> ↳ <code>:compile</code></h3>

  This project configuration entry adds the specified items as flags to compilation of C 
  components in a test executable's build.
  
  Flags may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus flag list. Both are documented below.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:test</code> ↳ <code>:link</code></h3>

  This project configuration entry adds the specified items as flags to the link step of 
  test executables.
  
  Flags may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus flag list. Both are documented below.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:&lt;plugin context&gt;</code></h3>

  Some advanced plugins make use of build contexts as well. For instance, the Ceedling 
  Gcov plugin uses a context of `:gcov`, surprisingly enough. For any plugins with tools
  that take advantage of Ceedling's internal mechanisms, you can add to those tools'
  flags in the same manner as the built-in contexts and operations.

### Simple `:flags` configuration

A simple and common need is enforcing a particular C standard. The following example
illustrates simple YAML lists for flags.

```yaml
:flags:
  :release:
    :compile:
      - -std=c99  # Add `-std=c99` to compilation of all C files in the release build
  :test:
    :compile:
      - -std=c99  # Add `-std=c99` to the compilation of all C files in all test executables
```

Given the YAML blurb above, when test or release compilation occurs, the flag specifying 
the C standard will be in the command line for compilation of all C files.

### Advanced `:flags` per-test matchers

Ceedling treats each test executable as a mini project. As a reminder, each test file,
together with all C sources and frameworks, becomes an individual test executable of
the same name.

_In the `:test` context only_, flags can be applied to build step operations — 
preprocessing, compilation, and linking — for only those test executables that match
file name criteria. Matchers match on test file names only, and the specified flags 
are added to the build step for all files that are components of matched test 
executables.

In short, for instance, this means your compilation of _TestA_ can have different flags
than compilation of _TestB_. And, in fact, those flags will be applied to every C file
that is compiled as part those individual test executable builds.

#### `:flags` per-test matcher examples with YAML

Before detailing matcher capabilities and limits, here are examples to illustrate the
basic ideas of test file name matching.

```yaml
:flags:
  :test:
    :compile:
      :*:                       #  Wildcard: Add '-foo' for all files for all tests
        - -foo                  
      :Model:                   # Substring: Add '-Wall' for all files of any test with 'Model' in its name
        - -Wall
      :/M(ain|odel)/:           #     Regex: Add 🏴‍☠️ flag for all files of any test with 'Main' or 'Model' in its name
        - -🏴‍☠️
      :Comms*Model:
        - --freak               #  Wildcard: Add your `--freak` flag for all files of any test name with zero or more
                                #            characters between 'Comms' and 'Model'
    :link:
      :tests/comm/TestUsart.c:  # Substring: Add '--bar --baz' to the link step of the TestUsart executable
        - --bar
        - --baz
```

#### Using `:flags` per-test matchers

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

Flags by matcher are cumulative. This means the flags from more than one matcher can be 
applied to an operation on any one test executable.

Referencing the example above, here are the extra compilation flags for a handful of 
test executables:

* _test_Something_: `-foo`
* _test_Main_: `-foo -🏴‍☠️`
* _test_Model_: `-foo -Wall -🏴‍☠️`
* _test_CommsSerialModel_: `-foo -Wall -🏴‍☠️ --freak`

The simple `:flags` list format remains available for the `:test` context. The YAML 
blurb below is equivalent to the plain wildcard matcher above. Of course, this format is 
limited in that it applies flags to all C files for all test executables.

```yaml
:flags:
  :test:
    :compile:  # Equivalent to wildcard '*' test file matching
      - -foo
```

#### Distinguishing similar or identical filenames with `:flags` per-test matchers

You may find yourself needing to distinguish test files with the same name or test 
files with names whose base naming is identical.

Of course, identical test filenames have a natural distinguishing feature in their 
containing directory paths. Files of the same name can only exist in different
directories. As such, your matching must include the path.

```yaml
:flags:
  :test:
    :compile:
      :hardware/test_startup:  # Match any test names beginning with 'test_startup' in hardware/ directory
        - A                  
      :network/test_startup:   # Match any test names beginning with 'test_startup' in network/ directory
        - B
```

It's common in C file naming to use the same base name for multiple files. Given the
following example list, care must be given to matcher construction to single out
test_comm_startup.c.

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

#### Using YAML anchors & aliases for complex testing scenarios with `:flags`

See the short but helpful article on [YAML anchors & aliases][yaml-anchors-aliases] to 
understand these features of YAML.

Particularly in testing complex projects, per-test file matching may only get you so
far in meeting your build step flag needs. For instance, you may need to set various
flags for operations across many test files, but no convenient name matching scheme 
works. Advanced YAML features can help you copy the same flags into multiple `:flags` 
test file matchers.

Please see the discussion in `:defines` for a complete example.

## `:import` Load additional project config files

In some cases it is nice to have config files (project.yml, options files) which can
load other config files, for commonly re-used definitions (target processor,
common code modules, etc).

These can be recursively nested, the included files can include other files.

To import config files, either provide an array of files to import, or use hashes to set imports. The former is useful if you do not anticipate needing to replace a given file for different configurations (project: or options:). If you need to replace/remove imports based on different configuration files, use the hashed version. The two methods cannot be mixed in the same .yml.

### Example `:import` YAML blurbs

Using array:

```yaml
:import:
  - path/to/config.yml
  - path/to/another/config.yml
```

Using hashes:

```yaml
:import:
  :configA: path/to/config.yml
  :configB: path/to/another/config.yml
```

## `:cexception` Configure CException’s features

* `:defines`:

  List of symbols used to configure CException's features in its source and header files 
  at compile time.
  
  See [Using Unity, CMock & CException](#using-unity-cmock--cexception) for much more on
  configuring and making use of these frameworks in your build.
  
  To manage overall command line length, these symbols are only added to compilation when
  a CException C source file is compiled.
  
  No symbols must be set unless CException's defaults are inappropriate for your 
  environment and needs.
  
  Note CException must be enabled for it to be added to a release or test build and for 
  these symbols to be added to a build of CException (see link referenced earlier for more).
  
  **Default**: `[]` (empty)

## `:cmock` Configure CMock’s code generation & compilation

Ceedling sets values for a subset of CMock settings. All CMock
options are available to be set, but only those options set by
Ceedling in an automated fashion are documented below. See CMock
documentation.

Ceedling sets values for a subset of CMock settings. All CMock 
options are available to be set, but only those options set by 
Ceedling in an automated fashion are documented below. 
See [CMock] documentation.

* `:enforce_strict_ordering`:

  Tests fail if expected call order is not same as source order

  **Default**: TRUE

* `:mock_path`:

  Path for generated mocks

  **Default**: <build path>/tests/mocks

* `:verbosity`:

  If not set, defaults to Ceedling's verbosity level

* `:defines`:

  Adds list of symbols used to configure CMock's C code features in its source and header 
  files at compile time.
  
  See [Using Unity, CMock & CException](#using-unity-cmock--cexception) for much more on
  configuring and making use of these frameworks in your build.
  
  To manage overall command line length, these symbols are only added to compilation when
  a CMock C source file is compiled.
  
  No symbols must be set unless CMock's defaults are inappropriate for your environment 
  and needs.
  
  **Default**: `[]` (empty)

* `:plugins`:

  To add to the list Ceedling provides CMock, simply add `:cmock` ↳ `:plugins` 
  to your configuration and specify your desired additional plugins.

  See [CMock's documentation][cmock-docs] to understand plugin options.

  [cmock-docs]: https://github.com/ThrowTheSwitch/CMock/blob/master/docs/CMock_Summary.md

* `:includes`:

  If `:cmock` ↳ `:unity_helper` set, prepopulated with unity_helper file
  name (no path).

  The `:cmock` ↳ `:includes` list works identically to the plugins list
  above with regard to adding additional files to be inserted within
  mocks as #include statements.

### Notes on Ceedling’s nudges for CMock strict ordering

The last four settings above are directly tied to other Ceedling
settings; hence, why they are listed and explained here.

The first setting above, `:enforce_strict_ordering`, defaults
to `FALSE` within CMock. However, it is set to `TRUE` by default 
in Ceedling as our way of encouraging you to use strict ordering.

Strict ordering is teeny bit more expensive in terms of code 
generated, test execution time, and complication in deciphering 
test failures. However, it's good practice. And, of course, you 
can always disable it by overriding the value in the Ceedling 
project configuration file.

## `:unity` Configure Unity’s features

* `:defines`:

  Adds list of symbols used to configure Unity's features in its source and header files
  at compile time.
  
  See [Using Unity, CMock & CException](#using-unity-cmock--cexception) for much more on
  configuring and making use of these frameworks in your build.
  
  To manage overall command line length, these symbols are only added to compilation when
  a Unity C source file is compiled.
  
  No symbols must be set unless Unity's defaults are inappropriate for your environment 
  and needs.
  
  **Default**: `[]` (empty)

## `:test_runner` Configure test runner generation

TODO: ...

## `:tools` Configuring command line tools used for build steps

Ceedling requires a variety of tools to work its magic. By default, the GNU 
toolchain (`gcc`, `cpp`, `as`) are configured and ready for use with no 
additions to the project configuration YAML file. However, as most work will 
require a project-specific toolchain, Ceedling provides a generic means for 
specifying / overriding tools.

* `:test_compiler`:

  Compiler for test & source-under-test code

   - `${1}`: Input source
   - `${2}`: Output object
   - `${3}`: Optional output list
   - `${4}`: Optional output dependencies file
   - `${5}`: Header file search paths
   - `${6}`: Command line #defines

  **Default**: `gcc`

* `:test_linker`:

  Linker to generate test fixture executables

   - `${1}`: input objects
   - `${2}`: output binary
   - `${3}`: optional output map
   - `${4}`: optional library list
   - `${5}`: optional library path list

  **Default**: `gcc`

* `:test_fixture`:

  Executable test fixture

   - `${1}`: simulator as executable with`${1}` as input binary file argument or native test executable

  **Default**: `${1}`

* `:test_includes_preprocessor`:

  Extractor of #include statements

   - `${1}`: input source file

  **Default**: `cpp`

* `:test_file_preprocessor`:

  Preprocessor of test files (macros, conditional compilation statements)
   - `${1}`: input source file
   - `${2}`: preprocessed output source file

  **Default**: `gcc`

* `:release_compiler`:

  Compiler for release source code

   - `${1}`: input source
   - `${2}`: output object
   - `${3}`: optional output list
   - `${4}`: optional output dependencies file

  **Default**: `gcc`

* `:release_assembler`:

  Assembler for release assembly code

   - `${1}`: input assembly source file
   - `${2}`: output object file

  **Default**: `as`

* `:release_linker`:

  Linker for release source code

   - `${1}`: input objects
   - `${2}`: output binary
   - `${3}`: optional output map
   - `${4}`: optional library list
   - `${5}`: optional library path list

  **Default**: `gcc`

### Tool configurable elements:

1. `:executable` - Command line executable (required).

    Note: If an executable contains a space (e.g. `Code Cruncher`), and the 
    shell executing the command line generated from the tool definition needs 
    the name quoted, add escaped quotes in the YAML:

    ```yaml
    :tools:
      :test_compiler:
        :executable: \"Code Cruncher\"
    ```

1. `:arguments` - List (array of strings) of command line arguments and 
    substitutions (required).

1. `:name` - Simple name (i.e. "nickname") of tool beyond its
   executable name. This is optional. If not explicitly set 
   then Ceedling will form a name from the tool's YAML entry.

1. `:stderr_redirect` - Control of capturing `$stderr` messages
   {`:none`, `:auto`, `:win`, `:unix`, `:tcsh`}.
   Defaults to `:none` if unspecified. Create a custom entry by
   specifying a simple string instead of any of the recognized
   symbols.

1. `:optional` - By default a tool is required for operation, which
   means tests will be aborted if the tool is not present. However,
   you can set this to `true` if it's not needed for testing (e.g.
   as part of a plugin).

### Tool element runtime substitution

To accomplish useful work on multiple files, a configured tool will most often
require that some number of its arguments or even the executable itself change
for each run. Consequently, every tool's argument list and executable field
possess two means for substitution at runtime. Ceedling provides two kinds of
inline Ruby execution and a notation for populating elements with dynamically
gathered values within the build environment.

#### Tool element runtime substitution: Inline Ruby execution

In-line Ruby execution works similarly to that demonstrated for the
`:environment` section except that substitution occurs as the tool is executed
and not at the time the configuration file is first scanned.

* `"#{...}"`:

  Ruby string substitution pattern wherein the containing string is expanded to
  include the string generated by Ruby code between the braces. Multiple
  instances of this expansion can occur within a single tool element entry
  string.

  Note: If this string substitution pattern is used, the entire string should be
  enclosed in quotes (see the `:environment` section for further explanation on
  this point).

* `{...}`:

  If an entire tool element string is enclosed with braces, it signifies that
  Ceedling should execute the Ruby code contained within those braces. Say you
  have a collection of paths on disk and some of those paths include spaces.
  Further suppose that a single tool that must use those paths requires those
  spaces to be escaped, but all other uses of those paths requires the paths to
  remain unchanged. You could use this Ceedling feature to insert Ruby code
  that iterates those paths and escapes those spaces in the array as used by
  the tool of this example.

#### Tool element runtime substitution: Notational substitution

A Ceedling tool's other form of dynamic substitution relies on a `$`
notation. These `$` operators can exist anywhere in a string and can be
decorated in any way needed. To use a literal `$`, escape it as `\\$`.

* `$`:

  Simple substitution for value(s) globally available within the runtime
  (most often a string or an array).

* `${#}`:

  When a Ceedling tool's command line is expanded from its configured
  representation and used within Ceedling Ruby code, certain calls to
  that tool will be made with a parameter list of substitution values.
  Each numbered substitution corresponds to a position in a parameter
  list. Ceedling Ruby code expects that configured compiler and linker
  tools will contain `${1}` and `${2}` replacement arguments. In the case of
  a compiler `${1}` will be a C code file path, and `${2}` will be the file
  path of the resulting object file. For a linker `${1}` will be an array
  of object files to link, and `${2}` will be the resulting binary
  executable. For an executable test fixture `${1}` is either the binary
  executable itself (when using a local toolchain such as GCC) or a
  binary input file given to a simulator in its arguments.

### Example `:tools` YAML blurb

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

#### `:tools` example blurb notes

* `${#}` is a replacement operator expanded by Ceedling with various
  strings, lists, etc. assembled internally. The meaning of each 
  number is specific to each predefined default tool (see 
  documentation above).

* See [search path order][##-search-path-order] to understand how 
  the `-I"${5}"` term is expanded.

* At present, `$stderr` redirection is primarily used to capture
  errors from test fixtures so that they can be displayed at the
  conclusion of a test run. For instance, if a simulator detects
  a memory access violation or a divide by zero error, this notice
  might go unseen in all the output scrolling past in a terminal.

* The built-in preprocessing tools _can_ be overridden with 
  non-GCC equivalents. However, this is highly impractical to do
  as preprocessing features are highly dependent on the 
  idiosyncrasies and features of the GCC toolchain.

#### Example Test Compiler Tooling

Resulting compiler command line construction from preceding example
`:tools` YAML blurb…

```shell
> compiler -I"/usr/include” -I”project/tests”
  -I"project/tests/support” -I”project/source” -I”project/include”
  -DTEST -DLONG_NAMES -network-license -optimize-level 4 arg-foo
  arg-bar arg-baz -c project/source/source.c -o
  build/tests/out/source.o
```

Notes on compiler tooling example:

- `arg-foo arg-bar arg-baz` is a fabricated example string collected from 
  `$stdout` as a result of shell execution of `args.exe`.
- The `-c` and `-o` arguments are fabricated examples simulating a single 
  compilation step for a test; `${1}` & `${2}` are single files.

#### Example Test Linker Tooling

Resulting linker command line construction from preceding example
`:tools` YAML blurb…

```shell
> \programs\acme\bin\linker.exe thing.o unity.o
  test_thing_runner.o test_thing.o mock_foo.o mock_bar.o -lfoo-lib
  -lbar-lib -o build\tests\out\test_thing.exe
```

Notes on linker tooling example:

- In this scenario `${1}` is an array of all the object files needed to 
  link a test fixture executable.

#### Example Test Fixture Tooling

Resulting test fixture command line construction from preceding example
`:tools` YAML blurb…

```shell
> tools\bin\acme_simulator.exe -mem large -f "build\tests\out\test_thing.bin 2>&1”
```

Notes on test fixture tooling example:

1. `:executable` could have simply been `${1}` if we were compiling
   and running native executables instead of cross compiling. That is,
   if the output of the linker runs on the host system, then the test
   fixture _is_ `${1}`.
1. We're using `$stderr` redirection to allow us to capture simulator error 
   messages to `$stdout` for display at the run's conclusion.

## `:plugins` Ceedling extensions

See the section below dedicated to plugins for more information. This section
pertains to enabling plugins in your project configuration.

Ceedling includes a number of built-in plugins. See the collection within
the project at [plugins/][ceedling-plugins] or the [documentation section below](#ceedling-plugins)
dedicated to Ceedling's plugins. Each built-in plugin subdirectory includes 
thorough documentation covering its capabilities and configuration options. 

_Note_: Many users find that the handy-dandy [Command Hooks plugin][command-hooks] 
is often enough to meet their needs. This plugin allows you to connect your own
scripts and command line tools to Ceedling build steps.

[custom-plugins]: PluginDevelopmentGuide.md
[ceedling-plugins]: ../plugins/
[command-hooks]: ../plugins/command_hooks/

* `:load_paths`:

  Base paths to search for plugin subdirectories or extra Ruby functionality.

  Ceedling maintains the Ruby load path for its built-in plugins. This list of
  paths allows you to add your own directories for custom plugins or simpler
  Ruby files referenced by your Ceedling configuration options elsewhere.

  **Default**: `[]` (empty)

* `:enabled`:

  List of plugins to be used - a plugin's name is identical to the
  subdirectory that contains it.

  **Default**: `[]` (empty)

Plugins can provide a variety of added functionality to Ceedling. In
general use, it's assumed that at least one reporting plugin will be
used to format test results (usually `report_tests_pretty_stdout`).

If no reporting plugins are specified, Ceedling will print to `$stdout` the
(quite readable) raw test results from all test fixtures executed.

### Example `:plugins` YAML blurb

```yaml
:plugins:
  :load_paths:
    - project/tools/ceedling/plugins  # Home to your collection of plugin directories.
    - project/support                 # Home to some ruby code your custom plugins share.
  :enabled:
    - report_tests_pretty_stdout      # Nice test results at your command line.
    - our_custom_code_metrics_report  # You created a plugin to scan all code to collect 
                                      # line counts and complexity metrics. Its name is a
                                      # subdirectory beneath the first `:load_path` entry.

```

<br/>

# Build Directive Macros

## Overview of Build Directive Macros

Ceedling supports a small number of build directive macros. At present,
these macros are only for use in test files.

By placing these macros in your test files, you may control aspects of an 
individual test executable's build from within the test file itself.

These macros are actually defined in Unity, but they evaluate to empty 
strings. That is, the macros do nothing. But, by placing them in your 
test files they communicate instructions to Ceedling when scanned at 
the beginning of a test build.

## `TEST_SOURCE_FILE()`

### `TEST_SOURCE_FILE()` Purpose

The `TEST_SOURCE_FILE()` build directive allows the simple injection of 
a specific source file into a test executable's build.

The Ceedling convention of compiling and linking any C file that 
corresponds in name to an `#include`d header file does not always work.
The alternative of `#include`ing a source file directly is ugly and can
cause other problems.

`TEST_SOURCE_FILE()` is also likely the best method for adding an assembly 
file to the build of a given test executable — if assembly support is
enabled for test builds.

### `TEST_SOURCE_FILE()` Example

```c
// Test file test_mycode.c
#include "unity.h"
#include "somefile.h"

// There is no file.h in this project to trigger Ceedling's convention.
// Compile file.c and link into test_mycode executable.
TEST_SOURCE_FILE("foo/bar/file.c")

void setUp(void) {
  // Do some set up
}

// ...
```

## `TEST_INCLUDE_PATH()`

### `TEST_INCLUDE_PATH()` Purpose

The `TEST_INCLUDE_PATH()` build directive allows a header search path to
be injected into the build of an individual test executable.

This is only an additive customization. The path will be added to the 
base/common path list specified by `:paths`  ↳ `:include` in the project 
file. If no list is specified in the project file, `TEST_INCLUDE_PATH()` 
entries will comprise the entire header search path list.

Unless you have a pretty funky C project, at least one search path entry
— however formed — is necessary for every test executable.

Please see [Configuring Your Header File Search Paths][header-file-search-paths]
for an overview of Ceedling's conventions on header file search paths.

[header-file-search-paths]: #configuring-your-header-file-search-paths

### `TEST_INCLUDE_PATH()` Example

```c
// Test file test_mycode.c
#include "unity.h"
#include "somefile.h"

// Add the following to the compiler's -I search paths used to
// compile all components comprising the test_mycode executable.
TEST_INCLUDE_PATH("foo/bar/")
TEST_INCLUDE_PATH("/usr/local/include/baz/")

void setUp(void) {
  // Do some set up
}

// ...
```

<br/>

# Ceedling Plugins

Ceedling includes a number of plugins. See the collection of built-in [plugins/][ceedling-plugins] 
or consult the list with summaries and links to documentation in the subsection 
that follows. Each plugin subdirectory includes full documentation of its 
capabilities and configuration options.

To enable built-in plugins or your own custom plugins, see the documentation for
the `:plugins` section in Ceedling project configuation options.

Many users find that the handy-dandy [Command Hooks plugin][command-hooks] 
is often enough to meet their needs. This plugin allows you to connect your own
scripts and tools to Ceedling build steps.

As mentioned, you can create your own plugins. See the [guide][custom-plugins] 
for how to create custom plugins.

[//]: # (Links in this section already defined above)

## Ceedling's built-in plugins, a directory

### Ceedling plugin `report_tests_pretty_stdout`

[This plugin][report_tests_pretty_stdout] is meant to tbe the default for
printing test results to the console. Without it, readable test results are
still produced but are not nicely formatted and summarized.

Plugin output includes a well-formatted list of summary statistics, ignored and
failed tests, and any extraneous output (e.g. `printf()` statements or
simulator memory errors) collected from executing the test fixtures.

Alternatives to this plugin are:
 
 * `report_tests_ide_stdout`
 * `report_tests_gtestlike_stdout`

Both of the above write to the console test results with a format that is useful
to IDEs generally in the case of the former, and GTest-aware reporting tools in
the case of the latter.

[report_tests_pretty_stdout]: ../plugins/report_tests_pretty_stdout

### Ceedling plugin `report_tests_ide_stdout`

[This plugin][report_tests_ide_stdout] prints to the console test results
formatted similarly to `report_tests_pretty_stdout` with one key difference.
This plugin's output is formatted such that an IDE executing Ceedling tasks can
recognize file paths and line numbers in test failures, etc.

This plugin's formatting is often recognized in an IDE's build window and
automatically linked for file navigation. With such output, you can select a
test result in your IDE's execution window and jump to the failure (or ignored
test) in your test file (more on using [IDEs] with Ceedling, Unity, and
CMock).

If enabled, this plugin should be used in place of 
`report_tests_pretty_stdout`.

[report_tests_ide_stdout]: ../plugins/report_tests_ide_stdout

[IDEs]: https://www.throwtheswitch.org/ide

### Ceedling plugin `report_tests_teamcity_stdout`

[TeamCity] is one of the original Continuous Integration server products.

[This plugin][report_tests_teamcity_stdout] processes test results into TeamCity
service messages printed to the console. TeamCity's service messages are unique
to the product and allow the CI server to extract build steps, test results,
and more from software builds if present.

The output of this plugin is useful in actual CI builds but is unhelpful in
local developer builds. See the plugin's documentation for options to enable
this plugin only in CI builds and not in local builds.

[TeamCity]: https://jetbrains.com/teamcity
[report_tests_teamcity_stdout]: ../plugins/report_tests_teamcity_stdout

### Ceedling plugin `report_tests_gtestlike_stdout`

[This plugin][report_tests_gtestlike_stdout] collects test results and prints
them to the console in a format that mimics [Google Test's output][gtest-sample-output]. 
Google Test output is both human readable and recognized
by a variety of reporting tools, IDEs, and Continuous Integration servers.

If enabled, this plugin should be used in place of
`report_tests_pretty_stdout`.

[gtest-sample-output]:
https://subscription.packtpub.com/book/programming/9781800208988/11/ch11lvl1sec31/controlling-output-with-google-test
[report_tests_gtestlike_stdout]: ../plugins/report_tests_gtestlike_stdout

### Ceedling plugin `command_hooks`

[This plugin][command-hooks] provides a simple means for connecting Ceedling's build events to
Ceedling tool entries you define in your project configuration (see `:tools`
documentation). In this way you can easily connect your own scripts or command
line utilities to build steps without creating an entire custom plugin.

[//]: # (Links defined in a previous section)

### Ceedling plugin `module_generator`

A pattern emerges in day-to-day unit testing, especially in the practice of
Test- Driven Development. Again and again, one needs a triplet of a source
file, header file, and test file — scaffolded in such a way that they refer to
one another.

[This plugin][module_generator] allows you to save precious minutes by creating
these templated files for you with convenient command line tasks.

[module_generator]: ../plugins/module_generator

### Ceedling plugin `fff`

The Fake Function Framework, [FFF], is an alternative approach to [test doubles][test-doubles] 
than that used by CMock.

[This plugin][FFF-plugin] replaces Ceedling generation of CMock-based mocks and
stubs in your tests with FFF-generated fake functions instead.

[//]: # (FFF links are defined up in an introductory section explaining CMock)

### Ceedling plugin `beep`

[This plugin][beep] provides a simple audio notice when a test build completes suite
execution or fails due to a build error. It is intended to support developers
running time-consuming test suites locally (i.e. in the background).

The plugin provides a variety of options for emitting audio notificiations on
various desktop platforms.

[beep]: ../plugins/beep

### Ceedling plugin `bullseye`

[This plugin][bullseye-plugin] adds additional Ceedling tasks to execute tests
with code coverage instrumentation provided by the commercial code coverage
tool provided by [Bullseye]. The Bullseye tool provides visualization and report
generation from the coverage results produced by an instrumented test suite.

[bullseye]: http://www.bullseye.com
[bullseye-plugin]: ../plugins/bullseye

### Ceedling plugin `gcov`

[This plugin][gcov-plugin] adds additional Ceedling tasks to execute tests with GNU code
coverage instrumentation. Coverage reports of various sorts can be generated
from the coverage results produced by an instrumented test suite.

This plugin manages the use of up to three coverage reporting tools. The GNU
[gcov] tool provides simple coverage statitics to the console as well as to the
other supported reporting tools. Optional Python-based [GCovr] and .Net-based
[ReportGenerator] produce fancy coverage reports in XML, JSON, HTML, etc.
formats.

[gcov-plugin]: ../plugins/gcov
[gcov]: http://gcc.gnu.org/onlinedocs/gcc/Gcov.html
[GCovr]: https://www.gcovr.com/
[ReportGenerator]: https://reportgenerator.io

### Ceedling plugin `report_tests_log_factory`

[This plugin][report_tests_log_factory] produces any or all of three useful test
suite reports in JSON, JUnit, or CppUnit format. It further provides a
mechanism for users to create their own custom reports with a small amount of
custom Ruby rather than a full plugin.

[report_tests_log_factory]: ../plugins/report_tests_log_factory

### Ceedling plugin `report_build_warnings_log`

[This plugin][report_build_warnings_log] scans the output of build tools for console
warning notices and produces a simple text file that collects all such warning
messages.

[report_build_warnings_log]: ../plugins/report_build_warnings_log

### Ceedling plugin `report_tests_raw_output_log`

[This plugin][report_tests_raw_output_log] captures extraneous console output
generated by test executables — typically for debugging — to log files named
after the test executables.

[report_tests_raw_output_log]: ../plugins/report_tests_raw_output_log

### Ceedling plugin `subprojects`

[This plugin][subprojects] supports subproject release builds of static
libraries. It manages differing sets of compiler flags and linker flags that
fit the needs of different library builds.

[subprojects]: ../plugins/subprojects

### Ceedling plugin `dependencies`

[This plugin][dependencies] manages release build dependencies including
fetching those dependencies and calling a given dependenc's build process.
Ultimately, this plugin generates the components needed by your Ceedling
release build target.

[dependencies]: ../plugins/dependencies

### Ceedling plugin `compile_commands_json_db`

[This plugin][compile_commands_json_db] create a [JSON Compilation Database][json-compilation-database]. 
This file is useful to [any code editor or IDE][lsp-tools] that implements 
syntax highlighting, etc. by way of the LLVM project's [`clangd`][clangd] 
Language Server Protocol conformant language server.

[compile_commands_json_db]: ../plugins/compile_commands_json_db
[lsp-tools]: https://microsoft.github.io/language-server-protocol/implementors/tools/
[clangd]: https://clangd.llvm.org
[json-compilation-database]: https://clang.llvm.org/docs/JSONCompilationDatabase.html

<br/>

# Global Collections

Collections are Ruby arrays and Rake FileLists (that act like 
arrays). Ceedling did work to populate and assemble these by
processing the project file, using internal knowledge, 
expanding path globs, etc. at startup.

Collections are globally available Ruby constants. These 
constants are documented below. Collections are also available
via accessors on the `Configurator` object (same names but all
lower case methods).

Global collections are typically used in Rakefiles, plugins, 
and Ruby scripts where the contents tend to be especially 
handy for crafting custom functionality.

Once upon a time collections were a core component of Ceedling.
As the tool has grown in sophistication and as many of its 
features now operate per test executable, the utility of and
number of collections has dwindled. Previously, nearly all
Ceedling actions happened in bulk and with the same 
collections used for all tasks. This is no longer true.

* `COLLECTION_PROJECT_OPTIONS`:

  All project option files with path found in the configured 
  options paths having the configured YAML file extension.

* `COLLECTION_ALL_TESTS`:

  All files with path found in the configured test paths 
  having the configured source file extension. 

* `COLLECTION_ALL_ASSEMBLY`:

  All files with path found in the configured source and 
  test support paths having the configured assembly file 
  extension. 

* `COLLECTION_ALL_SOURCE`:

  All files with path found in the configured source paths 
  having the configured source file extension. 

* `COLLECTION_ALL_HEADERS`:

  All files with path found in the configured include, 
  support, and test paths having the configured header file 
  extension. 

* `COLLECTION_ALL_SUPPORT`:

  All files with path found in the configured test support 
  paths having the configured source file extension. 

* `COLLECTION_PATHS_INCLUDE`:

  All configured include paths.

* `COLLECTION_PATHS_SOURCE`:

  All configured source paths.

* `COLLECTION_PATHS_SUPPORT`:

  All configured support paths.

* `COLLECTION_PATHS_TEST`:

  All configured test paths.

* `COLLECTION_PATHS_SOURCE_AND_INCLUDE`:

  All configured source and include paths.

* `COLLECTION_PATHS_SOURCE_INCLUDE_VENDOR`:

  All configured source and include paths plus applicable 
  vendor paths (Unity's source path plus CMock and 
  CException's source paths if mocks and exceptions are 
  enabled).

* `COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE`:

  All configured test, support, source, and include paths.

* `COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE_VENDOR`:

  All test, support, source, include, and applicable 
  vendor paths (Unity's source path plus CMock and 
  CException's source paths if mocks and exceptions are 
  enabled).

* `COLLECTION_PATHS_RELEASE_TOOLCHAIN_INCLUDE`:

  All configured release toolchain include paths.

* `COLLECTION_PATHS_TEST_TOOLCHAIN_INCLUDE`:

  All configured test toolchain include paths.

* `COLLECTION_PATHS_VENDOR`:

  Unity's source path plus CMock and CException's source 
  paths if mocks and exceptions are enabled.

* `COLLECTION_VENDOR_FRAMEWORK_SOURCES`:

  Unity plus CMock, and CException's .c filenames (without 
  paths) if mocks and exceptions are enabled.

* `COLLECTION_RELEASE_BUILD_INPUT`:

   * All files with path found in the configured source 
     paths having the configured source file extension.
   * If exceptions are enabled, the source files for 
     CException.
   * If assembly support is enabled, all assembly files 
     found in the configured paths having the configured 
     assembly file extension.

* `COLLECTION_EXISTING_TEST_BUILD_INPUT`:

   * All files with path found in the configured source 
     paths having the configured source file extension.
   * All files with path found in the configured test 
     paths having the configured source file extension.
   * Unity's source files.
   * If exceptions are enabled, the source files for 
     CException.
   * If mocks are enabled, the C source files for CMock.
   * If assembly support is enabled, all assembly files 
     found in the configured paths having the configured 
     assembly file extension.

  This collection does not include .c files generated by 
  Ceedling and its supporting frameworks at build time 
  (e.g. test runners and mocks). Further, this collection 
  does not include source files added to a test 
  executable's build list with the `TEST_SOURCE_FILE()` 
  build directive macro.

* `COLLECTION_RELEASE_ARTIFACT_EXTRA_LINK_OBJECTS`:

  If exceptions are enabled, CException's .c filenames 
  (without paths) remapped to configured object file 
  extension.

* `COLLECTION_TEST_FIXTURE_EXTRA_LINK_OBJECTS`:

  All test support source filenames (without paths) 
  remapped to configured object file extension.

<br/>
