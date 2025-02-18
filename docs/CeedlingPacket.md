
# Ceedling

All code is copyright © 2010-2025 Ceedling Project
by Michael Karlesky, Mark VanderVoord, and Greg Williams.

This Documentation is released under a
[Creative Commons 4.0 Attribution Share-Alike Deed][CC4SA].

[CC4SA]: https://creativecommons.org/licenses/by-sa/4.0/deed.en

# Quick Start

Ceedling is a fancypants build system that greatly simplifies building 
C projects. While it can certainly build release targets, it absolutely 
shines at running unit test suites.

## Steps

Below is a quick overview of how to get started from Ceedling installation 
through running build tasks. Jump down just a teeny bit to see what the Ceedling 
command line looks like and navigate to all the documentation for the steps 
listed immediately below.

1. Install Ceedling
1. Create a project
   * Use Ceedling to generate an example project, or
   * Add a Ceedling project file to the root of an existing project, or
   * Create a project from scratch:
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

## Ceedling Command Line & Build Tasks

Once you have Ceedling installed, you always have access to `ceedling help`.

And, once you have Ceedling installed, you have options for project creation
using Ceedling’s application commands:

* `ceedling new <name> <destination>`
* `ceedling examples` to list available example projects and 
  `ceedling example <name> <destination>` to create a readymade sample 
   project whose project file you can copy and modify.

Once you have a Ceedling project file and a project directory structure for your
code, Ceedling build tasks go like this:

* `ceedling test:MyCodeModule`, or
* `ceedling test:all`, or
* `ceedling release`, or, if you fancy and have the GCov plugin enabled,
* `ceedling clobber test:all gcov:all release --log --verbosity=obnoxious`

## Quick Start Documentation

* [Installation][quick-start-1]
* [Sample test code file + Example Ceedling projects][quick-start-2]
* [Simple Ceedling project file][quick-start-3]
* [Ceedling at the command line][quick-start-4]
* [All your Ceedling project configuration file options][quick-start-5]

[quick-start-1]: #ceedling-installation--set-up
[quick-start-2]: #commented-sample-test-file
[quick-start-3]: #simple-sample-project-file
[quick-start-4]: #now-what-how-do-i-make-it-go-the-command-line
[quick-start-5]: #the-almighty-project-configuration-file-in-glorious-yaml

<br/>

---

# Contents

(Be sure to review **[breaking changes](BreakingChanges.md)** if you are working with
a new release of Ceedling.)

Building test suites in C requires much more scaffolding than for
a release build. As such, much of Ceedling’s documentation is concerned
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

1. **[Now What? How Do I Make It _GO_? The Command Line.][packet-section-7]**

   Ceedling’s command line.

1. **[Important Conventions & Behaviors][packet-section-8]**

   Much of what Ceedling accomplishes — particularly in testing — is by convention. 
   Code and files structured and named in certain ways trigger sophisticated 
   Ceedling build features. This section explains all such conventions.

   This section also covers essential high-level behaviors and features including 
   how to work with search paths, directory structures & file extensions, release 
   build binary artifacts, build time logging, and Ceedling’s abilities to 
   preprocess certain code files before they are incorporated into a test build.

1. **[Using Unity, CMock & CException][packet-section-9]**

   Not only does Ceedling direct the overall build of your code, it also links 
   together several key tools and frameworks. Those can require configuration of 
   their own. Ceedling facilitates this.

1. **[How to Load a Project Configuration. You Have Options, My Friend.][packet-section-10]**

   You can use a command line flag, an environment variable, or rely on a default
   file in your working directory to load your base configuration.

   Once your base project configuration is loaded, you have **_Mixins_** for merging 
   additional configuration for different build scenarios as needed via command line, 
   environment variable, and/or your project configuration file.

1. **[The Almighty Ceedling Project Configuration File (in Glorious YAML)][packet-section-11]**

   This is the exhaustive documentation for all of Ceedling’s project file 
   configuration options — from project paths to command line tools to plugins and
   much, much more.

1. **[Which Ceedling][packet-section-12]**

   Sometimes you may need to point to a different Ceedling to run.

1. **[Build Directive Macros][packet-section-13]**

   These code macros can help you accomplish your build goals When Ceedling’s 
   conventions aren’t enough.

1. **[Ceedling Plugins][packet-section-14]**

   Ceedling is extensible. It includes a number of built-in plugins for code coverage,
   test report generation, continuous integration reporting, test file scaffolding 
   generation, sophisticated release builds, and more.

1. **[Global Collections][packet-section-15]**

   Ceedling is built in Ruby. Collections are globally available Ruby lists of paths,
   files, and more that can be useful for advanced customization of a Ceedling project 
   file or in creating plugins.

[packet-section-1]:  #ceedling-a-c-build-system-for-all-your-mad-scientisting-needs
[packet-section-2]:  #ceedling-unity-and-c-mocks-testing-abilities
[packet-section-3]:  #how-does-a-test-case-even-work
[packet-section-4]:  #commented-sample-test-file
[packet-section-5]:  #anatomy-of-a-test-suite
[packet-section-6]:  #ceedling-installation--set-up
[packet-section-7]:  #now-what-how-do-i-make-it-go-the-command-line
[packet-section-8]:  #important-conventions--behaviors
[packet-section-9]:  #using-unity-cmock--cexception
[packet-section-10]: #how-to-load-a-project-configuration-you-have-options-my-friend
[packet-section-11]: #the-almighty-ceedling-project-configuration-file-in-glorious-yaml
[packet-section-12]: #which-ceedling
[packet-section-13]: #build-directive-macros
[packet-section-14]: #ceedling-plugins
[packet-section-15]: #global-collections

---

<br/>

# Ceedling, a C Build System for All Your Mad Scientisting Needs

Ceedling allows you to generate an entire test and release build 
environment for a C project from a single, short YAML configuration 
file.

Ceedling and its bundled tools, Unity, CMock, and CException, don’t 
want to brag, but they’re also quite adept at supporting the tiniest of 
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

See this [commented project file][example-config-file] 
for a much more complete and sophisticated example of a project 
configuration.

See the later [configuration section][project-configuration] for 
way more details on your project configuration options.

A facility for [plugins](#ceedling-plugins) also allows you to 
extend Ceedling’s capabilities for needs such as custom code metrics 
reporting, build artifact packaging, and much more. A variety of 
built-in plugins come with Ceedling.

[example-config-file]: ../assets/project.yml
[project-configuration]: #the-almighty-ceedling-project-configuration-file-in-glorious-yaml

## What’s with This Name?

Glad you asked. Ceedling is tailored for unit tested C projects and is built
upon Rake, a Make replacement implemented in the Ruby scripting language.

So, we've got C, our Rake, and the fertile soil of a build environment in which
to grow and tend your project and its unit tests. Ta da — _Ceedling_.

Incidentally, though Rake was the backbone of the earliest versions of
Ceedling, it is now being phased out incrementally in successive releases
of this tool. The name Ceedling is not going away, however!

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
programming languages." It's kinda like a markup language but don’t
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

In reality, we’re probably not testing the static value of an integer 
against itself. Instead, we’re calling functions in our source code
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

Remember, the generated mock code you can’t see here has a whole bunch 
of smarts and Unity assertions inside it. CMock scans header files and
then generates mocks (C code) from the function signatures it finds in
those header files. It's kinda magical.

### That was the basics, but you’ll need more

For more on the assertions and mocking shown above, consult the 
documentation for [Unity] and [CMock] or the resources in
Ceedling’s [README][/README.md].

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

After absorbing this sample code, you’ll have context for much
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

Ceedling comes with entire example projects you can extract.

1. Execute `ceedling examples` in your terminal to list available example 
   projects.
1. Execute `ceedling example <project> [destination]` to extract the 
   named example project.

You can inspect the _project.yml_ file and source & test code. Run 
`ceedling help` from the root of the example projects to see what you can
do, or just go nuts with `ceedling test:all`.

<br/>

# Anatomy of a Test Suite

A Ceedling test suite is composed of one or more individual test executables.

The [Unity] project provides the actual framework for test case assertions 
and unit test sucess/failure accounting. If mocks are enabled, [CMock] builds 
on Unity to generate mock functions from source header files with expectation
test accounting. Ceedling is the glue that combines these frameworks, your
project’s toolchain, and your source code into a collection of test 
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

You have two good options for installing and running Ceedling:

1. The Ceedling Ruby Gem
1. Prepackaged _MadScienceLab_ Docker images

The simplest way to get started with a local installation is to install 
Ceedling as a Ruby gem. Gems are simply prepackaged Ruby-based software.
Other options exist, but the Ceedling Gem is the best option for a local
installation. However, you will also need a compiler toolchain (e.g. GNU
Compiler Collection) plus any supporting tools used by any plugins you
enabled.

If you are familiar with the virtualization technology Docker, our premade
Docker images will get you started with Ceedling and all the accompanying
tools lickety split. Install Docker, pull down one of the _MadScienceLab_
images and go.

## Local Installation As a [Ruby Gem][ruby-gem]:

1. [Download and install Ruby][ruby-install]. Ruby 3 is required.

1. Use Ruby’s command line gem package manager to install Ceedling from
   the [RubyGems repository][rubygems-repo]: `gem install ceedling`.
   * Unity, CMock, and CException come along with Ceedling at no extra 
     charge.
   * Installing from the RubyGems repo will also install Ceedling’s 
     dependencies.
1. Execute Ceedling at command line to create example project
   or an empty Ceedling project in your filesystem (executing
   `ceedling help` first is, well, helpful).

[ruby-gem]: http://docs.rubygems.org/read/chapter/1
[ruby-install]: http://www.ruby-lang.org/en/downloads/
[rubygems-repo]: http://rubygems.org

### Gem install notes

Steps 1–2 above are a one-time affair for your local environment. 
When steps 1-2 are completed once, only step 3 is needed for each new 
code projects.

If you are working with prerelease versions of Ceedling or some other 
off-the-beaten-path installation scenario, you may want to directly 
install the Ceedling .gem file attached to any of the Github releases.
No problem.

The steps are similar to the preceding with two changes:

1. `gem install --local <ceedling .gem filepath>`
1. Any missing dependencies must be manually installed before 
installation of the local Ceedling gem will succeed. A local 
installation attempt will complain about any missing dependencies. 
Simply `gem install` them by name.

## _MadScienceLab_ Docker Images

As an alternative to local installation, fully packaged Docker images containing Ruby, Ceedling, the GCC toolchain, and more are also available. [Docker][docker-overview] is a virtualization technology that provides self-contained software bundles that are a portable, well-managed alternative to local installation of tools like Ceedling.

Four Docker image variants containing Ceedling and supporting tools exist. These four images are available for both Intel and ARM host platforms (Docker does the right thing based on your host environment). The latter includes ARM Linux and Apple’s M-series macOS devices.

1. **_[MadScienceLab][docker-image-base]_**. This image contains Ruby, Ceedling, CMock, Unity, CException, the GNU Compiler Collection (gcc), and a handful of essential C libraries and command line utilities.
1. **_[MadScienceLab Plugins][docker-image-plugins]_**. This image contains all of the above plus the command line tools that Ceedling’s built-in plugins rely on. Naturally, it is quite a bit larger than option (1) because of the additional tools and dependencies.
1. **_[MadScienceLab ARM][docker-image-arm]_**. This image mirrors (1) with the compiler toolchain replaced with the GNU `arm-none-eabi` variant. 
1. **_[MadScienceLab ARM + Plugins][docker-image-arm-plugins]_**. This image is (3) with the addition of all the complementary plugin tooling just like (2) provides.

See the Docker Hub pages linked above for more documentation on these images.

Just to be clear here, most users of the _MadScienceLab_ Docker images will probably care about the ability to run unit tests on your own host. If you are one of those users, no matter what host platform you are on — Intel or ARM — you’ll want to go with (1) or (2) above. The tools within the image will automatically do the right thing within your environment. Options (3) and (4) are most useful for specialized cross-compilation scenarios.

### _MadScienceLab_ Docker Image usage basics

To use a _MadScienceLab_ image from your local terminal:

1. [Install Docker][docker-install]
1. Determine:
   1. The local path of your Ceedling project
   1. The variant and revision of the Docker image you’ll be using
1. Run the container with:
   1. The Docker `run` command and `-it --rm` command line options
   1. A Docker volume mapping from the root of your project to the default project path inside the container (_/home/dev/project_)

See the command line examples in the following two sections.

Note that all of these somewhat lengthy command lines lend themselves well to being wrapped up in simple helper scripts specific to your project and directory structure.

### Run a _MadScienceLab_ Docker Image as an interactive terminal

When the container launches as shown below, it will drop you into a Z-shell command line that has access to all the tools and utilities available within the container. In this usage, the Docker container becomes just another terminal, including ending its execution with `exit`.

```shell
 > docker run -it --rm -v /my/local/project/path:/home/dev/project throwtheswitch/madsciencelab-plugins:1.0.0
```

Once the _MadScienceLab_ container’s command line is available, to run Ceedling, execute it just as you would after installing Ceedling locally:

```shell
 ~/project > ceedling help
```

```shell
 ~/project > ceedling new ...
```

```shell
 ~/project > ceedling test:all
```

### Run a _MadScienceLab_ Docker Image as a command line utility

Alternatively, you can run Ceedling through the _MadScienceLab_ Docker container directly from the command line as a command line utility. The general pattern is immediately below.

```shell
 > docker run --rm -v /my/local/project/path:/home/dev/project throwtheswitch/madsciencelab-plugins:1.0.0 <Ceedling command line>
```

As a specific example, to run all tests in a suite, the command line would be this:

```shell
 > docker run --rm -v /my/local/project/path:/home/dev/project throwtheswitch/madsciencelab-plugins:1.0.0 ceedling test:all
```

In this usage, the container starts, executes Ceedling, and then ends.

[docker-overview]: https://www.ibm.com/topics/docker
[docker-install]: https://www.docker.com/products/docker-desktop/

[docker-image-base]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab
[docker-image-plugins]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab-plugins
[docker-image-arm]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab-arm-none-eabi
[docker-image-arm-plugins]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab-arm-none-eabi-plugins

## Getting Started after Ceedling is Installed

1. Once Ceedling is installed, you’ll want to start to integrate it with new
   and old projects alike. If you wanted to start to work on a new project
   named `foo`, Ceedling can create the skeleton of the project using `ceedling
   new foo <destination>`. Likewise if you already have a project named `bar` 
   and you want to “inject” Ceedling into it, you would run `ceedling new bar 
   <destination>`, and Ceedling will create any files and directories it needs.

1. Now that you have Ceedling integrated with a project, you can start using it.
   A good starting point is to enable the [plugin](#ceedling-plugins) 
   `module_generator` in your project configuration file and create a source +
   test code module to get accustomed to Ceedling by issuing the command 
   `ceedling 'module:create[name]'`.

## Grab Bag of Ceedling Notes

1. Certain advanced features of Ceedling rely on `gcc` and `cpp` as
   preprocessing tools. In most Linux systems, these tools are already available.
   For Windows environments, we recommend the 
   [MinGW project](http://www.mingw.org/) (Minimalist GNU for Windows). This 
   represents an optional, additional setup / installation step to complement 
   the list above. Upon installing MinGW ensure your system path is updated or 
   set `:environment` ↳ `:path` in your project configuration (see `:environment`
   section).

1. When using Ceedling in Windows environments, a test filename should not
   include the sequences “patch” or “setup”. After a test build these test
   filenames will become test executables. Windows Installer Detection Technology
   (part of UAC) requires administrator privileges to execute filenames including
   these strings.

<br/>

# Now What? How Do I Make It _GO_? The Command Line.

We’re getting a little ahead of ourselves here, but it's good
context on how to drive this bus. Everything is done via the command
line. We'll cover project conventions and how to actually configure
your project in later sections.

For now, let's talk about the command line.

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

## Quick command line example to get you started

To exercise the Ceedling command line quickly, follow these steps after 
[installing Ceedling](#ceedling-installation--set-up):

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

* `ceedling build <tasks...>` or `ceedling <tasks...>`:

  Runs the named build tasks. `build` is optional (i.e. `ceedling test:all` 
  is equivalent to `ceedling build test:all`). Various option flags
  exist to control project configuration loading, verbosity levels, 
  logging, test task filters, etc.

  See next section to understand the build & plugin tasks this application
  command is able to execute. Run `ceedling help build` to understand all
  the command line flags that work with build & plugin tasks.

* `ceedling dumpconfig`:

  Process project configuration and write final result to a YAML file. 
  Various option flags exist to control project configuration loading,
  configuration manipulation, and configuration sub-section extraction.

* `ceedling environment`:

  Lists project related environment variables:

  * All environment variable names and string values added to your 
    environment from within Ceedling and through the `:environment`
    section of your configuration. This is especially helpful in 
    verifying the evaluation of any string replacement expressions in
    your `:environment` config entries.
  * All existing Ceedling-related environment variables set before you
    ran Ceedling from the command line.

* `ceedling example`:

  Extracts an example project from within Ceedling to your local 
  filesystem. The available examples are listed with 
  `ceedling examples`. Various option flags control whether the example
  contains vendored Ceedling and/or a documentation bundle.

* `ceedling examples`:

  Lists the available examples within Ceedling. To extract an example,
  use `ceedling example`.

* `ceedling help`:

  Displays summary help for all application commands and detailed help 
  for each command. `ceedling help` also loads your project 
  configuration (if available) and lists all build tasks from it. 
  Various option flags control what project configuration is loaded.

* `ceedling new`:

  Creates a new project structure. Various option flags control whether 
  the new project contains vendored Ceedling, a documentation bundle,
  and/or a starter project configuration file.

* `ceedling upgrade`:

  Upgrade vendored installation of Ceedling for an existing project 
  along with any locally installed documentation bundles.

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

* `ceedling test:all`:

  Run all unit tests.

* `ceedling test:*`:

  Execute the named test file or the named source file that has an
  accompanying test. No path. Examples: `ceedling test:foo`, `ceedling 
  test:foo.c` or `ceedling test:test_foo.c`

* `ceedling test:* --test-case=<test_case_name> `
  Execute individual test cases which match `test_case_name`.

  For instance, if you have a test file _test_gpio.c_ containing the following 
  test cases (test cases are simply `void test_name(void)`:

    - `test_gpio_start`
    - `test_gpio_configure_proper`
    - `test_gpio_configure_fail_pin_not_allowed`

  … and you want to run only _configure_ tests, you can call:

    `ceedling test:gpio --test-case=configure`

  **Test case matching notes**

  * Test case matching is on sub-strings. `--test_case=configure` matches on
    the test cases including the word _configure_, naturally. 
    `--test-case=gpio` would match all three test cases.

* `ceedling test:* --exclude_test_case=<test_case_name> `
  Execute test cases which do not match `test_case_name`.

  For instance, if you have file test_gpio.c with defined 3 tests:

    - `test_gpio_start`
    - `test_gpio_configure_proper`
    - `test_gpio_configure_fail_pin_not_allowed`

  … and you want to run only start tests, you can call:

    `ceedling test:gpio --exclude_test_case=configure`

  **Test case exclusion matching notes**

  * Exclude matching follows the same sub-string logic as discussed in the
    preceding section.

* `ceedling test:pattern[*]`:

  Execute any tests whose name and/or path match the regular expression
  pattern (case sensitive). Example: `ceedling "test:pattern[(I|i)nit]"` 
  will execute all tests named for initialization testing.

  _NOTE:_ Quotes are likely necessary around the regex characters or 
  entire task to distinguish characters from shell command line operators.

* `ceedling test:path[*]`:

  Execute any tests whose path contains the given string (case
  sensitive). Example: `ceedling test:path[foo/bar]` will execute all tests
  whose path contains foo/bar. _Notes:_

  1. Both directory separator characters `/` and `\` are valid.
  1. Quotes may be necessary around the task to distinguish the parameter's
     characters from shell command line operators.

* `ceedling release`:

  Build all source into a release artifact (if the release build option
  is configured).

* `ceedling release:compile:*`:

  Sometimes you just need to compile a single file dagnabit. Example:
  `ceedling release:compile:foo.c`

* `ceedling release:assemble:*`:

  Sometimes you just need to assemble a single file doggonit. Example:
  `ceedling release:assemble:foo.s`

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

## Ceedling Command Line Tasks, Extra Credit

### Combining Tasks At the Command Line

Multiple build tasks can be executed at the command line.

For example, `ceedling clobber test:all release` will remove all generated
files; build and run all tests; and then build all source — in that order. If
any task fails along the way, execution halts before the next task.

Task order is executed as provided and can be important! Running `clobber` after
a `test:` or `release:` task will not accomplish much.

### Build Directory and Revision Control

The `clobber` task removes certain build directories in the
course of deleting generated files. In general, it's best not
to add to source control any Ceedling generated directories
below the root of your top-level build directory. That is, leave
anything Ceedling & its accompanying tools generate out of source
control (but go ahead and add the top-level build directory that
holds all that stuff if you want).

### Logging decorators

Ceedling attempts to bring more joy to your console logging. This may include
fancy Unicode characters, emoji, or color.

Example:
```
-----------------------
❌ OVERALL TEST SUMMARY
-----------------------
TESTED:  6
PASSED:  5
FAILED:  1
IGNORED: 0
```

By default, Ceedling makes an educated guess as to which platforms can best
support this. Some platforms (we’re looking at you, Windows) do not typically
have default font support in their terminals for these features. So, by default
this feature is disabled on problematic platforms while enabled on others.

An environment variable `CEEDLING_DECORATORS` forces decorators on or off with a
`true` (`1`) or `false` (`0`) string value.

If you find a monospaced font that provides emojis, etc. and works with Windows’
command prompt, you can (1) Install the font (2) change your command prompt’s
font (3) set `CEEDLING_DECORATORS` to `true`.

<br/>

# Important Conventions & Behaviors

**How to get things done and understand what’s happening during builds**

## Directory Structure, Filenames & Extensions

Much of Ceedling’s functionality is driven by collecting files
matching certain patterns inside the paths it's configured
to search. See the documentation for the `:extension` section
of your configuration file (found later in this document) to
configure the file extensions Ceedling uses to match and collect
files. Test file naming is covered later in this section.

Test files and source files must be segregated by directories.
Any directory structure will do. Tests can be held in subdirectories
within source directories, or tests and source directories
can be wholly separated at the top of your project’s directory
tree.

## Search Paths for Test Builds

Test builds in C are fairly complex. Each test file becomes a test
executable. Each test executable needs generated runner code and 
optionally generated mocks. Slicing and dicing what files are 
compiled and linked and how search paths are assembled is tricky
business. That’s why Ceedling exists in the first place. Because
of these issues, search paths, in particular, require quite a bit
of special handling.

Unless your project is relying exclusively on `extern` statements and
uses no mocks for testing, Ceedling _**must**_ be told where to find 
header files. Without search path knowledge, mocks cannot be generated, 
and test file compilation will fail for lack of symbol definitions
and function declarations.

Ceedling provides two mechanisms for configuring search paths:

1. The [`:paths` ↳ `:include`](#paths--include) section within your 
   project file (or mixin files).
1. The [`TEST_INCLUDE_PATH(...)`](#test_include_path) build directive 
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
1. Internal path for Unity’s unit test framework C code
1. Internal paths for CMock and CException’s C code (if respective 
   features enabled)
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

## Search Paths for Release Builds

Unlike test builds, release builds are relatively straightforward. Each
source file is compiled into an object file. All object files are linked.
A Ceedling release build may optionally compile and link in CException
and can handle linking in libraries as well.

Search paths for release builds are configured with `:paths` ↳ `:include` 
in your project configuration. That’s about all there is to it.

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
can be quite simple. As a bonus, you’ll never forget to wire up 
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

## Ceedling preprocessing behavior for your tests

### Preprocessing feature background and overview

Ceedling and CMock are advanced tools that both perform fairly sophisticated
parsing.

However, neither of these tools fully understands the entire C language,
especially C’s preprocessing statements.

If your test files rely on macros and `#ifdef` conditionals used in certain
ways (see examples below), there’s a chance that Ceedling will break on trying
to process your test files, or, alternatively, your test suite will build but 
not execute as expected.

Similarly, generating mocks of header files with macros and `#ifdef`
conditionals around or in function signatures can get weird. Of course, it’s 
often in sophisticated projects with complex header files that mocking is most 
desired in the first place.

Ceedling includes an optional ability to preprocess the following files before 
then extracting test cases and functions to be mocked with text parsing.

1. Your test files, or
1. Mockable header files, or
1. Both of the above 

See the [`:project` ↳ `:use_test_preprocessor`][project-settings] project 
configuration setting.

This Ceedling feature uses `gcc`’s preprocessing mode and the `cpp` preprocessor 
tool to strip down / expand test files and headers to their raw code content 
that can then be parsed as text by Ceedling and CMock. These tools must be in 
your search path if Ceedling’s preprocessing is enabled.

**Ceedling’s test preprocessing abilities are directly tied to the features and 
output of `gcc` and `cpp`. The default Ceedling tool definitions for these should 
not be redefined for other toolchains. It is highly unlikely to work for you. 
Future Ceedling improvements will allow for a plugin-style ability to use your 
own tools in this highly specialized capacity.**

[project-settings]: #project-global-project-settings

### Ceedling preprocessing limitations and gotchas

#### Preprocessing limitations cheatsheet

Ceedling’s preprocessing abilities are generally quite useful — especially in 
projects with multiple build configurations for different feature sets or 
multiple targets, legacy code that cannot be refactored, and complex header 
files provided by vendors.

However, best applying Ceedling’s preprocessing abilities requires understanding 
how the feature works, when to use it, and its limitations.

At a high level, Ceedling’s preprocessing is applicable for cases where macros 
or conditional compilation preprocessing statements (e.g. `#ifdef`):

* Generate or hide/reveal your test files’ `#include` statements.
* Generate or hide/reveal your test files’ test case function signatures 
  (e.g. `void test_foo()`.
* Generate or hide/reveal mockable header files’ `#include` statements.
* Generate or hide/reveal header files’ mockable function signatures.

**_NOTE:_ You do not necessarily need to enable Ceedling’s preprocessing only
because you have preprocessing statements in your test files or mockable header 
files. The feature is only truly needed if your project meets the conditions 
above.**

The sections that follow flesh out the details of the bulleted list above.

#### Preprocessing gotchas

**_IMPORTANT:_ As of Ceedling 1.0.0, Ceedling’s test preprocessing feature 
has a limitation that affects Unity features triggered by the following macros.**

* `TEST_CASE()`
* `TEST_RANGE()`

`TEST_CASE()` and `TEST_RANGE()` are Unity macros that are positional in a file 
in relation to the test case functions they modify. While Ceedling's test file
preprocessing can preserve these macro calls, their position cannot be preserved.

That is, Ceedling’s preprocessing and these Unity features are not presently 
compatible. Note that it _is_ possible to enable preprocessing for mockable 
header files apart from enabling it for test files. See the documentation for
`:project` ↳ `:use_test_preprocessing`. This can allow test preprocessing in the 
common cases of sophtisticate mockable headers while Unity’s `TEST_CASE()` and 
`TEST_RANGE()` are utilized in a test file untouched by preprocessing.

**_IMPORTANT:_ The following new build directive macro `TEST_INCLUDE_PATH()` 
available in Ceedling 1.0.0 is incompatible with enclosing conditional 
compilation C preprocessing statements:**

Wrapping `TEST_INCLUDE_PATH()` in conditional compilation statements 
(e.g. `#ifdef`) will not behave as you expect. This macro is used as a marker
for advanced abilities discovered by Ceedling parsing a test file as plain text.
Whether or not Ceedling preprocessing is enabled, Ceedling will always discover 
this marker macro in the plain text of a test file.

Why is `TEST_INCLUDE_PATH()` incompatible with `#ifdef`? Well, it’s because of
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
* `TEST_INCLUDE_PATH()` & `TEST_SOURCE_FILE()` can be “hidden” from Ceedling’s
  text scanning with traditional C comments.

### Preprocessing of your test files

When preprocessing is enabled for test files, Ceedling will expand preprocessor
statements in test files before extracting `#include` conventions and test case 
signatures. That is, preprocessing output is used to generate test runners 
and assemble the components of a test executable build.

**_NOTE:_** Conditional directives _inside_ test case functions generally do 
not require Ceedling’s test preprocessing ability. Assuming your code is correct,
the C preprocessor within your toolchain will do the right thing for you
in your test build. Read on for more details and the other cases of interest.

Test file preprocessing by Ceedling is applicable primarily when conditional
preprocessor directives generate the `#include` statements for your test file
and/or generate or enclose full test case functions. Ceedling will not be able 
to properly discover your `#include` statements or test case functions unless 
they are plainly available in an expanded, raw code version of your test file. 
Ceedling’s preprocessing abilities provide that expansion.

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

### Preprocessing of mockable header files

When preprocessing is enabled for mocking, Ceedling will expand preprocessor 
statements in header files before generating mocks from them. CMock requires
a clear look at function definitions and types in order to do its work.

Header files with preprocessor directives and conditional macros can easily
obscure details from CMock’s limited C parser. Advanced C projects tend
to rely on preprocessing directives and macros to accomplish everything from
build variants to OS calls to register access to managing proprietary language
extensions.

Mocking is often most useful in complicated codebases. As such Ceedling’s 
preprocessing abilities tend to be quite necessary to properly expand header
files so CMock can parse them.

#### Examples of when Ceedling preprocessing **_is_** needed for mockable headers

Generally, Ceedling preprocessing is needed when:

1. Function signatures are formed by macros
1. Function signatures are conditionaly present due to surrounding `#ifdef` 
   statements
1. Macros expand to become function decorators, return types, or parameters 

**_Important Notes:_**

* Sometimes CMock’s parsing features can be configured to handle scenarios
  that fall within (3) above. CMock can match and remove most text strings,
  match and replace certain text strings, map custom types to mockable 
  alternatives, and be extended with a Unity helper to handle complex and 
  compound types. See [CMock]’s documentation for more.

* Test preprocessing causes any macros or symbols in a mockable header to 
  “disappear” in the generated mock. It’s quite common to have needed symbols
  or macros in a header file that do not directly impact the function 
  signatures to be mocked. This can break compilation of your test suite.

  Possible solutions to this problem include:

   1. Move symbols and macros in your header file that do not impact function 
      signatures to another source header file that will not be filtered
      by Ceedling’s header file preprocessing.
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

## Execution time (duration) reporting in Ceedling operations & test suites

### Ceedling’s logged run times

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

### Ceedling test suite and Unity test executable run durations

A test suite comprises one or more Unity test executables (see 
[Anatomy of a Test Suite][anatomy-test-suite]). Ceedling times indvidual Unity 
test executable run durations. It also sums these into a total test suite 
execution time. These duration values are typically used in generating test 
reports via plugins.

Not all test report formats utilize duration values. For those that do, some
effort is usually required to map Ceedling duration values to a relevant test 
suite abstraction within a given test report format.

Because Ceedling can execute builds with multiple threads, care must be taken
to interpret test suite duration values — particularly in relation to 
Ceedling’s logged run times.

In a multi-threaded build it's quite common for the logged Ceedling project run
time to be less than the total suite time in a test report. In multi-threaded 
builds on multi-core machines, test executables are run on different processors
simultaneously. As such, the total on-processor time in a test report can 
exceed the operation time Ceedling itself logs to the console. Further, because
multi-threading tends to introduce context switching and processor scheduling 
overhead, the run duration of a test executable may be reported as longer than
a in a comparable single-threaded build.

[anatomy-test-suite]: #anatomy-of-a-test-suite

### Unity test case run times

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
you’ll spare yourself headache if you let Ceedling delete and
regenerate files and directories in a non-versioned corner
of your project’s filesystem beneath the top-level build directory.

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

If you use the option for graceful failures in CI, you’ll want to
rig up some kind of logging monitor that scans Ceedling’s test
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

If you want to use mocks in your test cases, you’ll need to enable mocking 
and configure CMock with `:project` ↳ `:use_mocks` and the `:cmock` section 
of your project configuration respectively. CMock is fully supported by 
Ceedling but generally requires some set up for your project’s needs.

If you are incorporating CException into your release artifact, you’ll need 
to enable exceptions and configure CException with `:project` ↳ 
`:use_exceptions` and the `:cexception` section of your project 
configuration respectively. Enabling CException makes it available in both 
release builds and test builds.

This section provides a high-level view of how the various tools become
part of your builds and fit into Ceedling’s configuration file. Ceedling’s 
configuration file is discussed in detail in the next section.

See [Unity], [CMock], and [CException]’s project documentation for all 
your configuration options. Ceedling offers facilities for providing these
frameworks their compilation and configuration settings. Discussing 
these tools and all their options in detail is beyond the scope of Ceedling 
documentation.

## Unity Configuration

Unity is wholly compiled C code. As such, its configuration is entirely 
controlled by a variety of compilation symbols. These can be configured
in Ceedling’s `:unity` project settings.

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
    - UNITY_LINE_TYPE=\"unsigned int\"    # Apparently, we’re writing lengthy test files,
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
itself. Ceedling’s project file is something of a container for CMock's 
YAML configuration (Ceedling also uses CMock's configuration, though).

See the documentation for the top-level [`:cmock`][cmock-yaml-config] 
section within Ceedling’s project file.

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
These can be configured in Ceedling’s `:cexception` ↳ `:defines` project 
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

# How to Load a Project Configuration. You Have Options, My Friend.

Ceedling needs a project configuration to accomplish anything for you.
Ceedling's project configuration is a large in-memory data structure.
That data structure is loaded from a human-readable file format called
YAML.

The next section details Ceedling’s project configuration options in 
YAML. This section explains all your options for loading and modifying 
project configuration.

## Overview of Project Configuration Loading & Smooshing

Ceedling has a certain pipeline for loading and manipulating the 
configuration it uses to build your projects. It goes something like
this:

1. Load the base project configuration from a YAML file.
1. Merge the base configuration with zero or more Mixins from YAML files.
1. Load zero or more plugins that provide default configuration values
   or alter the base project configuration.
1. Populate the configuration with default values if anything was left
   unset to ensure all configuration needed to run is present.

Ceedling provides reasonably verbose logging at startup telling you which
configuration files were used and in what order they were merged.

For nitty-gritty details on plugin configuration behavior, see the
_[Plugin Development Guide](PluginDevelopmentGuide.md)_

## Options for Loading Your Base Project Configuration

You have three options for telling Ceedling what single base project 
configuration to load. These options are ordered below according to their
precedence. If an option higher in the list is present, it is used.

1. Command line option flags
1. Environment variable
1. Default file in working directory

### `--project` command line flags

Many of Ceedling's [application commands][packet-section-7] include an 
optional `--project` flag. When provided, Ceedling will load as its base 
configuration the YAML filepath provided.

Example: `ceedling --project=my/path/build.yml test:all`

_NOTE:_ Ceedling loads any relative paths within your configuration in
relation to your working directory. This can cause a disconnect between
configuration paths, working directory, and the path to your project 
file.

If the filepath does not exist, Ceedling terminates with an error.

### Environment variable `CEEDLING_PROJECT_FILE`

If a `--project` flag is not used at the command line, but the 
environment variable `CEEDLING_PROJECT_FILE` is set, Ceedling will use
the path it contains to load your project configuration. The path can
be absolute or relative (to your working directory).

If the filepath does not exist, Ceedling terminates with an error.

### Default _project.yml_ in your working directory

If neither a `--project` command line flag nor the environment variable
`CEEDLING_PROJECT_FILE` are set, then Ceedling tries to load a file 
named _project.yml_ in your working directory.

If this file does not exist, Ceedling terminates with an error.

## Applying Mixins to Your Base Project Configuration

Once you have a base configuation loaded, you may want to modify it for
any number of reasons. Some example scenarios:

* A single project actually contains mutiple build variations. You would
  like to maintain a common configuration that is shared among build
  variations.
* Your repository contains the configuration needed by your Continuous
  Integration server setup, but this is not fun to run locally. You would
  like to modify the configuration locally with sources external to your
  repository.
* Ceedling's default `gcc` tools do not work for your project needs. You
  would like the complex tooling configurations you most often need to
  be maintained separately and shared among projects.

Mixins allow you to merge configuration with your project configuration
just after the base project file is loaded. The merge is so low-level
and generic that you can, in fact, load an empty base configuration 
and merge in entire project configurations through mixins.

## Mixins Example Plus Merging Rules

Let’s start with an example that also explains how mixins are merged.
Then, the documentation sections that follow will discuss everything
in detail.

### Mixins Example: Scenario

In this example, we will load a base project configuration and then
apply three mixins using each of the available means — command line,
envionment variable, and `:mixins` section in the base project 
configuration file.

#### Example environment variable

`CEEDLING_MIXIN_1` = `./env.yml`

#### Example command line

`ceedling --project=base.yml --mixin=support/mixins/cmdline.yml <tasks>`

_NOTE:_ The `--mixin` flag supports more than filepaths and can be used 
multiple times in the same command line for multiple mixins (see later 
documentation section). 

The example command line above will produce the following logging output.

```
🌱 Loaded project configuration from command line argument using base.yml
 + Merged command line mixin using support/mixins/cmdline.yml
 + Merged CEEDLING_MIXIN_1 mixin using ./env.yml
 + Merged project configuration mixin using ./enabled.yml
```

_Notes_

* The logging output above referencing _enabled.yml_ comes from the 
  `:mixins` section within the base project configuration file provided below.
* The resulting configuration in this example is missing settings required
  by Ceedling. This will cause a validation build error that is not shown
  here.

### Mixins Example: Configuration files

#### _base.yml_ — Our base project configuration file

Our base project configuration file:

1. Sets up a configuration file-baesd mixin. Ceedling will look for a mixin
   named _enabled_ in the specified load paths. In this simple configuration
   that means Ceedling looks for and merges _support/mixins/enabled.yml_.
1. Creates a `:project` section in our configuration.
1. Creates a `:plugins` section in our configuration and enables the standard 
   console test report output plugin.

```yaml
:mixins:              # `:mixins` section only recognized in base project configuration
  :enabled:           # `:enabled` list supports names and filepaths
    - enabled         # Ceedling looks for name as enabled.yml in load paths and merges if found
  :load_paths:
    - support/mixins

:project:
  :build_root: build/

:plugins:
  :enabled:
    - report_tests_pretty_stdout
```

#### _support/mixins/cmdline.yml_ — Mixin via command line filepath flag

This mixin will merge a `:project` section with the existing `:project`
section from the base project file per the deep merge rules (noted after 
the examples).

```yaml
:project:
  :use_test_preprocessor: :all
  :test_file_prefix: Test
```

#### _env.yml_ — Mixin via environment variable filepath

This mixin will merge a `:plugins` section with the existing `:plugins`
section from the base project file per the deep merge rules (noted 
after the examples).

```yaml
:plugins:
  :enabled:
    - compile_commands_json_db
```

#### _support/mixins/enabled.yml_ — Mixin via base project configuration file `:mixins` section

This mixin listed in the base configuration project file will merge
`:project` and `:plugins` sections with those that already exist from
the base configuration plus earlier mixin merges per the deep merge 
rules (noted after the examples).

```yaml
:project:
  :use_test_preprocessor: :none

:plugins:
  :enabled:
    - gcov
```

### Mixins Example: Resulting project configuration

Behold the project configuration following mixin merges:

```yaml
:project:
  :build_root: build/           # From base.yml
  :use_test_preprocessor: :all  # Value in support/mixins/cmdline.yml overwrote value from support/mixins/enabled.yml
  :test_file_prefix: Test       # Added to :project from support/mixins/cmdline.yml

:plugins:
  :enabled:                     # :plugins ↳ :enabled from two mixins merged with oringal list in base.yml
    - report_tests_pretty_stdout  # From base.yml
    - compile_commands_json_db    # From env.yml
    - gcov                        # From support/mixins/enabled.yml

# NOTE: Original :mixins section is filtered out of resulting config
```

### Mixins deep merge rules

Mixins are merged in a specific order. See the next documentation 
sections for details.

Smooshing of mixin configurations into the base project configuration
follows a few basic rules:

* If a configuration key/value pair does not already exist at the time
  of merging, it is added to the configuration.
* If a simple value — e.g. boolean, string, numeric — already exists 
  at the time of merging, that value is replaced by the value being
  merged in.
* If a container — e.g. list or hash — already exists at the time of a
  merge, the contents are _combined_. In the case of lists, merged 
  values are added to the end of the existing list.

_**Note:**_ That last bullet can have a significant impact on how your
various project configuration paths—including those used for header 
search paths—are ordered. In brief, the contents of your `:paths` 
from your base configuration will come first followed by any additions
from your mixins. See the section [Search Paths for Test Builds][test-search-paths]
for more.

[test-search-paths]: #search-paths-for-test-builds

## Options for Loading Mixins

You have three options for telling Ceedling what mixins to load. These 
options are ordered below according to their precedence. A Mixin higher
in the list is merged earlier. In addition, options higher in the list
force duplicate mixin filepaths to be ignored lower in the list.

Unlike base project file loading that resolves to a single filepath, 
multiple mixins can be specified using any or all of these options.

1. Command line option flags
1. Environment variables
1. Base project configuration file entries

### `--mixin` command line flags

As already discussed above, many of Ceedling's application commands 
include an optional `--project` flag. Most of these same commands 
also recognize optional `--mixin` flags. Note that `--mixin` can be 
used multiple times in a single command line.

When provided, Ceedling will load the specified YAML file and merge
it with the base project configuration.

A Mixin flag can contain one of two types of values:

1. A filename or filepath to a mixin yaml file. A filename contains
   a file extension. A filepath includes a leading directory path.
1. A simple name (no file extension and no path). This name is used
   as a lookup in Ceedling's mixin load paths.

Example: `ceedling --project=build.yml --mixin=foo --mixin=bar/mixin.yaml test:all`

Simple mixin names (#2 above) require mixin load paths to search.
A default mixin load path is always in the list and points to within
Ceedling itself (in order to host eventual built-in mixins like 
built-in plugins). User-specified load paths must be added through 
the `:mixins` section of the base configuration project file. See 
the [documentation for the `:mixins` section of your project 
configuration][mixins-config-section] for more details.

Order of precedence is set by the command line mixin order 
left-to-right.

Filepaths may be relative (in relation to the working directory) or
absolute.

If the `--mixin` filename or filepath does not exist, Ceedling 
terminates with an error. If Ceedling cannot find a mixin name in 
any load paths, it terminates with an error.

[mixins-config-section]: #base-project-configuration-file-mixins-section-entries

### Mixin environment variables

Mixins can also be loaded through environment variables. Ceedling
recognizes environment variables with a naming scheme of 
`CEEDLING_MIXIN_#`, where `#` is any number greater than 0.

Precedence among the environment variables is a simple ascending
sort of the trailing numeric value in the environment variable name.
For example, `CEEDLING_MIXIN_5` will be merged before 
`CEEDLING_MIXIN_99`.

Mixin environment variables only hold filepaths. Filepaths may be 
relative (in relation to the working directory) or absolute.

If the filepath specified by an environment variable does not exist,
Ceedling terminates with an error.

### Base project configuration file `:mixins` section entries

Ceedling only recognizes a `:mixins` section in your base project
configuration file. A `:mixins` section in a mixin is ignored. In addition,
the `:mixins` section of a base project configuration file is filtered
out of the resulting configuration.

The `:mixins` configuration section can contain up to two subsections.
Each subsection is optional.

* `:enabled`

  An optional array comprising (A) mixin filenames/filepaths and/or 
  (B) simple mixin names.

  1. A filename contains a file extension. A filepath includes a 
     directory path. The file content is YAML.
  1. A simple name (no file extension and no path) is used
     as a file lookup among any configured load paths (see next
     section) and as a lookup name among Ceedling’s built-in mixins
     (currently none).

  Enabled entries support [inline Ruby string expansion][inline-ruby-string-expansion].

  **Default**: `[]`

* `:load_paths`

  Paths containing mixin files to be searched via mixin names. A mixin
  filename in a load path has the form _<name>.yml_ by default. If
  an alternate filename extension has been specified in your project
  configuration (`:extension` ↳ `:yaml`) it will be used for file
  lookups in the mixin load paths instead of _.yml_.

  Searches start in the path at the top of the list.

  Both mixin names in the `:enabled` list (above) and on the command
  line via `--mixin` flag use this list of load paths for searches.

  Load paths entries support [inline Ruby string expansion][inline-ruby-string-expansion].
  
  **Default**: `[]`

Example `:mixins` YAML blurb:

```yaml
:mixins:
  :enabled:
    - foo            # Search for foo.yml in proj/mixins & support/ and 'foo' among built-in mixins
    - path/bar.yaml  # Merge this file with base project conig
  :load_paths:
    - proj/mixins
    - support
```

Relating the above example to command line `--mixin` flag handling:

* A command line flag of `--mixin=foo` is equivalent to the `foo` 
  entry in the `:enabled` mixin configuration.
* A command line flag of `--mixin=path/bar.yaml` is equivalent to the 
  `path/bar.yaml` entry in the `:enabled` mixin configuration.
* Note that while command line `--mixin` flags work identically to 
  entries in `:mixins` ↳ `:enabled`, they are merged first instead of 
  last in the mixin precedence.

<br/>

# The Almighty Ceedling Project Configuration File (in Glorious YAML)

See this [commented project file][example-config-file] for a nice 
example of a complete project configuration.

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
  Ceedling’s abilities. See the Ceedling plugin [subprojects] for
  extending release build abilities.

[MinGW]: http://www.mingw.org/

## Ceedling-specific YAML Handling & Conventions

### Inline Ruby string expansion

Ceedling is able to execute inline Ruby string substitution code within the
entries of certain project file configuration elements.

In some cases, this evaluation may occurs when elements of the project 
configuration are loaded and processed into a data structure for use by the 
Ceedling application (e.g. path handling). In other cases, this evaluation
occurs each time a project configuration element is referenced (e.g. tools).

_Notes:_
* One good option for validating and troubleshooting inline Ruby string 
  exapnsion is use of `ceedling dumpconfig` at the command line. This application
  command causes your project configuration to be processed and written to a 
  YAML file with any inline Ruby string expansions, well, expanded along with 
  defaults set, plugin actions applied, etc.
* A commonly needed expansion is that of referencing an environment variable.
  Inline Ruby string expansion supports this. See the example below.

#### Ruby string expansion syntax

To exapnd the string result of Ruby code within a configuration value string, 
wrap the Ruby code in the substitution pattern `#{…}`.

Inline Ruby string expansion may constitute the entirety of a configuration 
value string, may be embedded within a string, or may be used multiple times
within a string.

Because of the `#` it’s a good idea to wrap any string values in your YAML that
rely on this feature with quotation marks. Quotation marks for YAML strings are
optional. However, the `#` can cause a YAML parser to see a comment. As such,
explicitly indicating a string to the YAML parser with enclosing quotation 
marks alleviates this problem.

#### Ruby string expansion example

```yaml
:some_config_section:
  :some_key:
    - "My env string #{ENV['VAR1']}"
    - "My utility result string #{`util --arg`.strip()}"
```

In the example above, the two YAML strings will include the strings returned by
the Ruby code within `#{…}`:

1. The first string uses Ruby’s environment variable lookup `ENV[…]` to fetch 
the value assigned to variable `VAR1`.
1. The second string uses Ruby’s backtick shell execution ``…`` to insert the 
string generated by a command line utility.

#### Project file sections that offer inline Ruby string expansion

* `:mixins`
* `:environment`
* `:paths` plus any second tier configuration key name ending in `_path` or
  `_paths`
* `:flags`
* `:defines`
* `:tools`
* `:release_build` ↳ `:artifacts`

See each section’s documentation for details.

[inline-ruby-string-expansion]: #inline-ruby-string-expansion

### Path handling

Any second tier setting keys anywhere in YAML whose names end in `_path` or
`_paths` are automagically processed like all Ceedling-specific paths in the
YAML to have consistent directory separators (i.e. `/`) and to take advantage
of inline Ruby string expansion (see preceding section for details).

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
internally — thus leading to unexpected behavior without warning.

## `:project`: Global project settings

**_NOTE:_** In future versions of Ceedling, test-specific and release-specific
build settings presently organized beneath `:project` will likely be renamed 
and migrated to the `:test_build` and `:release_build` sections.

* `:build_root`

  Top level directory into which generated path structure and files are
  placed. NOTE: this is one of the handful of configuration values that
  must be set. The specified path can be absolute or relative to your
  working directory.

  **Default**: (none)

* `:default_tasks`

  A list of default build / plugin tasks Ceedling should execute if 
  none are provided at the command line.

  _NOTE:_ These are build & plugin tasks (e.g. `test:all` and `clobber`).
  These are not application commands (e.g. `dumpconfig`) or command 
  line flags (e.g. `--verbosity`). See the documentation 
  [on using the command line][command-line] to understand the distinction 
  between application commands and build & plugin tasks.

  Example YAML:
  ```yaml
  :project:
    :default_tasks:
      - clobber
      - test:all
      - release
  ```
  **Default**: `['test:all']`

  [command-line]: #now-what-how-do-i-make-it-go-the-command-line

* `:use_mocks`

  Configures the build environment to make use of CMock. Note that if
  you do not use mocks, there's no harm in leaving this setting as its
  default value.

  **Default**: TRUE

* `:use_test_preprocessor`

  This option allows Ceedling to work with test files that contain
  tricky conditional compilation statements (e.g. `#ifdef`) as well as mockable 
  header files containing conditional preprocessor directives and/or macros.

  See the [documentation on test preprocessing][test-preprocessing] for more.

  With any preprocessing enabled, the `gcc` & `cpp` tools must exist in an
  accessible system search path.

   * `:none` disables preprocessing.
   * `:all` enables preprocessing for all mockable header files and test C files.
   * `:mocks` enables only preprocessing of header files that are to be mocked.
   * `:tests` enables only preprocessing of your test files.

  See also the complementary setting `:use_deep_preprocessor`.

  [test-preprocessing]: #preprocessing-behavior-for-tests

  **Default**: `:none`

* `:use_deep_preprocessor`

  This option is an addon to `:use_test_preprocessor`. It is **_only_** 
  appropriate to enable this setting if you are also using `:use_test_preprocessor`
  and _only_ if Ceedling’s test preprocessing configuration includes mock generation.

  This setting allows Ceedling to better support limited amd specific situations 
  where definitions required for test builds might be buried in your source files’ 
  `#include` chain and not ending up injected into generated mocks.

  At present, when enabled, this setting only injects a far lengthier list of `#include` 
  directives in your generated mocks. The most common need for this is in 
  projects with complex source code where CMock’s sophisticated `inline` mocking feature 
  is enabled.

  Except in rare cases, **_you probably do not need this feature_**. It will add some
  overhead to your build and you risk oddball problems like doubly-defined symbols
  and other such problems from using more `#include` directives than are probably needed 
  in your generated mocks.

  If compilation of your mocks is failing for lack of symbols (because of incomplete
  `#include` lists in said mocks), you have other options to try besides this setting:

  1. Using `:cmock` ↳ `:includes` (or its variations) to manually inject needed header
     files into generated mocks.
  1. Go spelunking through your project to find any `#define`s your source code relies
     on in a release build that should be duplicated in a test build. If `#include`
     statements are surrounded by conditional compilation preprocessing statements 
     without the corresponding triggering conditions in your test build, the 
     GCC preproccessor Ceedling relies on will not discover all the `#include` 
     statements in the dependencies chain and thus will not be able to inject them
     into generated mocks. See Ceeling’s extensive support for adding symbols to your
     test build in the `:defines` project configuration section.

  Available options:

   * `:none` disables deep preprocessing, leaving normal shallow mode.
   * `:mocks` enables deep preprocessing of header files that are to be mocked.

  **Default**: `:none`

* `:test_file_prefix`

  Ceedling collects test files by convention from within the test file
  search paths. The convention includes a unique name prefix and a file
  extension matching that of source files.

  Why not simply recognize all files in test directories as test files?
  By using the given convention, we have greater flexibility in what we
  do with C files in the test directories.

  **Default**: "test_"

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

* `:which_ceedling`

  This is an advanced project option primarily meant for development work
  on Ceedling itself. This setting tells the code that launches the 
  Ceedling application where to find the code to launch.

  This entry can be either a directory path or `gem`.

  See the section [Which Ceedling](#which_ceedling) for full details.

  **Default**: `gem`

* `:use_backtrace`

  When a test executable encounters a ☠️ **Segmentation Fault** or other crash 
  condition, the executable immediately terminates and no further details for 
  test suite reporting are collected.

  But, fear not. You can bring your dead unit tests back to life.

  By default, in the case of a crash, Ceedling reruns the test executable for
  each test case using a special mode to isolate that test case. In this way
  Ceedling can iteratively identify which test cases are causing the crash or
  exercising release code that is causing the crash. Ceedling then assembles
  the final test reporting results from these individual test case runs.

  You have three options for this setting, `:none`, `:simple` or `:gdb`:

  1. `:none` will simply cause a test report to list each test case as failed
     due to a test executable crash.

     Sample Ceedling run output with backtrace `:none`:

     ```
     👟 Executing
     ------------
     Running TestUsartModel.out...
     ☠️ ERROR: Test executable `TestUsartModel.out` seems to have crashed

     -------------------
     FAILED TEST SUMMARY
     -------------------
     [test/TestUsartModel.c]
       Test: testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting
       At line (24): "Test executable crashed"

       Test: testCrash
       At line (37): "Test executable crashed"

       Test: testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately
       At line (44): "Test executable crashed"

       Test: testShouldReturnErrorMessageUponInvalidTemperatureValue
       At line (50): "Test executable crashed"

       Test: testShouldReturnWakeupMessage
       At line (56): "Test executable crashed"

     -----------------------
     ❌ OVERALL TEST SUMMARY
     -----------------------
     TESTED:  5
     PASSED:  0
     FAILED:  5
     IGNORED: 0
     ```

  1. `:simple` causes Ceedling to re-run each test case in the 
     test executable individually to identify and report the problematic 
     test case(s). This is the default option and is described above.

     Sample Ceedling run output with backtrace `:simple`:

     ```
     👟 Executing
     ------------
     Running TestUsartModel.out...
     ☠️ ERROR: Test executable `TestUsartModel.out` seems to have crashed
     
     -------------------
     FAILED TEST SUMMARY
     -------------------
     [test/TestUsartModel.c]
       Test: testCrash
       At line (37): "Test case crashed"
     
     -----------------------
     ❌ OVERALL TEST SUMMARY
     -----------------------
     TESTED:  5
     PASSED:  4
     FAILED:  1
     IGNORED: 0
     ```

  1. `:gdb` uses the [`gdb`][gdb] debugger to identify and report the 
     troublesome line of code triggering the crash. If this option is enabled, 
     but `gdb` is not available to Ceedling, project configuration validation 
     will terminate with an error at startup.

     Sample Ceedling run output with backtrace `:gdb`:

     ```
     👟 Executing
     ------------
     Running TestUsartModel.out...
     ☠️ ERROR: Test executable `TestUsartModel.out` seems to have crashed
     
     -------------------
     FAILED TEST SUMMARY
     -------------------
     [test/TestUsartModel.c]
       Test: testCrash
       At line (40): "Test case crashed >> Program received signal SIGSEGV, Segmentation fault.
                     0x00005618066ea1fb in testCrash () at test/TestUsartModel.c:40
                     40    uint32_t i = *nullptr;"
     
     -----------------------
     ❌ OVERALL TEST SUMMARY
     -----------------------
     TESTED:  5
     PASSED:  4
     FAILED:  1
     IGNORED: 0
     ```

  **_Notes:_**

  1. The default of `:simple` only works in an environment capable of
     using command line arguments (passed to the test executable). If you are
     targeting a simulator with your test executable binaries, `:simple` is
     unlikely to work for you. In the simplest case, you may simply fall back
     to `:none`. With some work and using Ceedling’s various features, much 
     more sophisticated options are possible.
  1. The `:gdb` option currently only supports the native build platform. 
     That is, the `:gdb` backtrace option cannot handle backtrace for 
     cross-compiled code or any sort of simulator-based test fixture.

  **Default**: `:simple`

  [gdb]: https://www.sourceware.org/gdb/

### Example `:project` YAML blurb

```yaml
:project:
  :build_root: project_awesome/build
  :use_exceptions: FALSE
  :use_test_preprocessor: :all
  :release_build: TRUE
  :compile_threads: :auto
```

## `:mixins` Configuring mixins to merge

This section of a project configuration file is documented in the
[discussion of project files and mixins][mixins-config-section].

**_Notes:_**

* A `:mixins` section is only recognized within a base project configuration 
  file. Any `:mixins` sections within mixin files are ignored.
* A `:mixins` section in a Ceedling configuration is entirely filtered out of
  the resulting configuration. That is, it is unavailable for use by plugins
  and will not be present in any output from `ceedling dumpconfig`.
* A `:mixins` section supports [inline Ruby string expansion][inline-ruby-string-expansion].
  See the full documetation on Mixins for details.

## `:test_build` Configuring a test build

**_NOTE:_** In future versions of Ceedling, test-related settings presently 
organized beneath `:project` will be renamed and migrated to this section.

* `:use_assembly`

  This option causes Ceedling to enable an assembler tool and collect a
  list of assembly file sources for use in a test suite build.

  The default assembler is the GNU tool `as`; like all other tools, it 
  may be overridden in the `:tools` section.

  After enabliing this feature, two conditions must be true in order to 
  inject assembly code into the build of a test executable:

  1. The assembly files must be visible to Ceedling by way of `:paths` and
  `:extension` settings for assembly files. Here, assembly files would be
  equivalent to C code files handled in the same ways.
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

**_NOTE:_** In future versions of Ceedling, release build-related settings 
presently organized beneath `:sproject` will be renamed and migrated to 
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

  By default, Ceedling copies to the _<build path>/artifacts/release_
  directory the output of the release linker and (optionally) a map
  file. Many toolchains produce other important output files as well.
  Adding a file path to this list will cause Ceedling to copy that file
  to the artifacts directory.

  The artifacts directory is helpful for organizing important build 
  output files and provides a central place for tools such as Continuous 
  Integration servers to point to build output. Selectively copying 
  files prevents incidental build cruft from needlessly appearing in the 
  artifacts directory.

  Note that [inline Ruby string expansion][inline-ruby-string-expansion]
  is available in artifact paths.

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

_**Note:**_ If you use Mixins to build up path lists in your project 
configuration, the merge order of those Mixins will dictate the ordering of
your path lists. Particularly given that the search path list built with
`:paths` ↳ `:include` you will want to pay attention to ordering issues
involved in specifying path lists in Mixins.

* <h3><code>:paths</code> ↳ <code>:test</code></h3>

  All C files containing unit test code. NOTE: this is one of the
  handful of configuration values that must be set for a test suite.

  **Default**: `[]` (empty)

* <h3><code>:paths</code> ↳ <code>:source</code></h3>

  All C files containing release code (code to be tested)

  NOTE: this is one of the handful of configuration values that must 
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
  That is, you list all path locations where your project’s header files
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

  Library search paths. [See `:libraries` section][libraries].

  **Default**: `[]` (empty)

  [libraries]: #libraries

* <h3><code>:paths</code> ↳ <code>:&lt;custom&gt;</code></h3>

  Any paths you specify for custom list. List is available to tool
  configurations and/or plugins. Note a distinction – the preceding names
  are recognized internally to Ceedling and the path lists are used to
  build collections of files contained in those paths. A custom list is
  just that - a custom list of paths.

### `:paths` configuration options & notes

1. A path can be absolute (fully qualified) or relative.
1. A path can include a glob matcher (more on this below).
1. A path can use [inline Ruby string expansion][inline-ruby-string-expansion].
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

_**Note:**_ The resolution of subtractive paths happens after your full paths
lists are assembled. So, if you use `:paths` entries in Mixins to build up your 
project configuration, subtractive paths will only be processed after the final 
mixin is merged. That is, you can merge in additive and subtractive paths with
Mixins to your heart’s content. The subtractive paths are not removed until all
Mixins have been merged.

### Example `:paths` YAML blurbs

_NOTE:_ Ceedling standardizes paths for you. Internally, all paths use forward
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

The command line option `ceedling dumpconfig` can also help your troubleshoot
your configuration file. This application command causes Ceedling to process
your configuration file and write the result to another YAML file for your 
inspection.

## `:files` Modify file collections

**File listings for tailoring file collections**

Ceedling relies on file collections to do its work. These file collections are
automagically assembled from paths, matching globs / wildcards, and file
extensions (see project configuration `:extension`).

Entries in `:files` accomplish filepath-oriented tailoring of the bulk file
collections created from `:paths` directory listings and filename pattern
matching.

On occasion you may need to remove from or add individual files to Ceedling’s
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
1. A path can use [inline Ruby string expansion][inline-ruby-string-expansion].
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

`:environment` is a list of single key / value pair entries processed in the 
configured list order.

`:environment` variable value strings can include 
[inline Ruby string expansion][inline-ruby-string-expansion]. Thus, later 
entries can reference earlier entries.

### Special case: `PATH` handling

In the specific case of specifying an environment key named `:path`, an array 
of string values will be concatenated with the appropriate platform-specific 
path separation character (i.e. `:` on Unix-variants, `;` on Windows).

All other instances of environment keys assigned a value of a YAML array use 
simple concatenation.

### Example `:environment` YAML blurb

Note that `:environment` is a list of key / value pairs. Only one key per entry
is allowed, and that key must be a `:`_<symbol>_.

```yaml
:environment:
  - :license_server: gizmo.intranet        # LICENSE_SERVER set with value "gizmo.intranet"
  - :license: "#{`license.exe`}"           # LICENSE set to string generated from shelling out to
                                           # execute license.exe; note use of enclosing quotes to
                                           # prevent a YAML comment.

  - :logfile: system/logs/thingamabob.log  # LOGFILE set with path for a log file

  - :path:                                 # Concatenated with path separator (see special case above)
     - Tools/gizmo/bin                     # Prepend existing PATH with gizmo path
     - "#{ENV['PATH']}"                    # Pattern #{…} triggers ruby evaluation string expansion
                                           # NOTE: value string must be quoted because of '#' to 
                                           # prevent a YAML comment.
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

Ceedling’s internal, default compiler tool configurations (see later `:tools` section) 
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

Ceedling _does_ validate your `:defines` block in your project configuration.

### `:defines` organization: Contexts and Matchers

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
      - <symbol> # List of symbols added to that subset's compilation
      - ...
  :preprocess:   # Only applicable if :project ↳ :use_test_preprocessor enabled
    :<matcher>   # Matches a subset of test executables
      - <symbol> # List of symbols added to that subset's compilation
      - ...
```

A context is the build context you want to modify — `:release`, `:preprocess`, or `:test`.
Plugins can also hook into `:defines` with their own context.

You specify the symbols you want to add to a build step beneath a `:<context>`. In many 
cases this is a simple YAML list of strings that will become symbols defined in a 
compiler's command line.

Specifically in the `:test` and `:preprocess` contexts you also have the option to 
create test file matchers that create symbol definitions for some subset of your build.

* <h3><code>:defines</code> ↳ <code>:release</code></h3>

  This project configuration entry adds the items of a simple YAML list as symbols to 
  the compilation of every C file in a release build.
  
  **Default**: `[]` (empty)

* <h3><code>:defines</code> ↳ <code>:test</code></h3>

  This project configuration entry adds the specified items as symbols to compilation of C 
  components in a test executable’s build.
  
  Symbols may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus symbol list. Both are documented below.

  Every C file that comprises a test executable build will be compiled with the symbols
  configured that match the test filename itself.
  
  **Default**: `[]` (empty)

* <h3><code>:defines</code> ↳ <code>:preprocess</code></h3>

  This project configuration entry adds the specified items as symbols to any needed 
  preprocessing of components in a test executable’s build. Preprocessing must be enabled 
  for this matching to have any effect. (See `:project` ↳ `:use_test_preprocessor`.)
  
  Preprocessing here refers to handling macros, conditional includes, etc. in header files 
  that are mocked and in complex test files before runners are generated from them.
  (See more about the [Ceedling preprocessing](#ceedling-preprocessing-behavior-for-your-tests) 
  feature.)
  
  Like the `:test` context, compilation symbols may be represented in a simple YAML list 
  or with a more sophisticated file matcher YAML key plus symbol list. Both are documented 
  below.
  
  _NOTE:_ Left unspecified, `:preprocess` symbols default to be identical to `:test` 
  symbols. Override this behavior by adding `:defines` ↳ `:preprocess` symbols. If you want 
  no additional symbols for preprocessing regardless of `test` symbols, specify an 
  empty list `[]` in your `:preprocess` matcher.
  
  **Default**: Identical to `:test` context unless specified

* <h3><code>:defines</code> ↳ <code>:&lt;plugin context&gt;</code></h3>

  Some advanced plugins make use of build contexts as well. For instance, the Ceedling 
  Gcov plugin uses a context of `:gcov`, surprisingly enough. For any plugins with tools
  that take advantage of Ceedling’s internal mechanisms, you can add to those tools'
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
  :test:     # All compilation of all C files for all test executables
    - FEATURE_X=ON
    - PRODUCT_CONFIG_C
  :release:  # All compilation of all C files in a release artifact
    - FEATURE_X=ON
    - PRODUCT_CONFIG_C
```

Given the YAML blurb above, the two symbols will be defined in the compilation command 
lines for all C files in all test executables within a test suite build and for all C 
files in a release build.

### Advanced `:defines` per-test matchers

Ceedling treats each test executable as a mini project. As a reminder, each test file,
together with all C sources and frameworks, becomes an individual test executable of
the same name.

**_In the `:test` and `:preprocess` contexts only_**, symbols may be defined for only 
those test executable builds that match filename criteria. Matchers match on test 
filenames only, and the specified symbols are added to the build step for all files 
that are components of matched test executables.

In short, for instance, this means your compilation of _TestA_ can have different 
symbols than compilation of _TestB_. Those symbols will be applied to every C file 
that is compiled as part those individual test executable builds. Thus, in fact, with 
separate test files unit testing the same source C file, you may exercise different 
conditional compilations of the same source. See the example in the section below.

#### `:defines` per-test matcher examples with YAML

Before detailing matcher capabilities and limits, here are examples to illustrate the
basic ideas of test file name matching.

This first example builds on the previous simple symbol list example. The imagined scenario
is that of unit testing the same single source C file with different product features 
enabled. The per-test matchers shown here use test filename substring matchers.

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

Symbols by matcher are cumulative. This means the symbols from multiple
matchers can be applied to all compilation for any single test executable.

Referencing the example above, here are the extra compilation symbols for a
handful of test executables:

* _test_Something_: `-DA`
* _test_Main_: `-DA -DBLESS_YOU`
* _test_Model_: `-DA -DCHOO -DBLESS_YOU`
* _test_CommsSerialModel_: `-DA -DCHOO -DBLESS_YOU -DTHANKS`

The simple `:defines` list format remains available for the `:test` and `:preprocess` 
contexts. Of course, this format is limited in that it applies symbols to the 
compilation of all C files for all test executables.

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

The following advanced example illustrates how to create a set of compilation symbols 
for test preprocessing that are identical to test compilation with one addition.

In brief, this example uses YAML features to copy the `:test` matcher configuration
that matches all test executables into the `:preprocess` context and then add an 
additional compilation symbol to the list.

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

Ceedling’s internal, default tool configurations execute compilation and linking of test 
and source files among a variety of other tooling needs. (See later `:tools` section.)

These default tool configurations are a one-size-fits-all approach. If you need to add 
flags to the command line for individual tests or a release build, the `:flags` section
allows you to easily do so.

Entries in `:flags` modify the command lines for tools used at build time.

### Flags organization: Contexts, Operations, and Matchers

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

A context is the build context you want to modify — `:test` or `:release`. Plugins can
also hook into `:flags` with their own context.

An operation is the build step you wish to modify — `:preprocess`, `:compile`, `:assemble`, 
or `:link`.

* The `:preprocess` operation is only used from within the `:test` context.
* The `:assemble` operation is only of use within the `:test` or `:release` contexts if 
  assembly support has been enabled in `:test_build` or `:release_build`, respectively, and
  assembly files are a part of the project.

You specify the flags you want to add to a build step beneath `:<context>` ↳ `:<operation>`.
In many cases this is a simple YAML list of strings that will become flags in a tool's 
command line.

**_Specifically and only in the `:test` context_** you also have the option to create test 
file matchers that apply flags to some subset of your test build. Note that file matchers 
and the simpler flags list format cannot be mixed for `:flags` ↳ `:test`.

* <h3><code>:flags</code> ↳ <code>:release</code> ↳ <code>:compile</code></h3>

  This project configuration entry adds the items of a simple YAML list as flags to 
  compilation of every C file in a release build.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:release</code> ↳ <code>:link</code></h3>

  This project configuration entry adds the items of a simple YAML list as flags to 
  the link step of a release build artifact.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:test</code> ↳ <code>:compile</code></h3>

  This project configuration entry adds the specified items as flags to compilation of C 
  components in a test executable's build.
  
  Flags may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus flag list. Both are documented below.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:test</code> ↳ <code>:preprocess</code></h3>

  This project configuration entry adds the specified items as flags to any needed 
  preprocessing of components in a test executable’s build. Preprocessing must be enabled 
  for this matching to have any effect. (See `:project` ↳ `:use_test_preprocessor`.)
  
  Preprocessing here refers to handling macros, conditional includes, etc. in header files 
  that are mocked and in complex test files before runners are generated from them.
  (See more about the [Ceedling preprocessing](#ceedling-preprocessing-behavior-for-your-tests) 
  feature.)
  
  Flags may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus flag list. Both are documented below.
  
  _NOTE:_ Left unspecified, `:preprocess` flags default to behaving identically to `:compile` 
  flags. Override this behavior by adding `:test` ↳ `:preprocess` flags. If you want no 
  additional flags for preprocessing regardless of test compilation flags, simply specify 
  an empty list `[]`.
  
  **Default**: Same flags as specified for test compilation

* <h3><code>:flags</code> ↳ <code>:test</code> ↳ <code>:link</code></h3>

  This project configuration entry adds the specified items as flags to the link step of 
  test executables.
  
  Flags may be represented in a simple YAML list or with a more sophisticated file matcher
  YAML key plus flag list. Both are documented below.
  
  **Default**: `[]` (empty)

* <h3><code>:flags</code> ↳ <code>:&lt;plugin context&gt;</code></h3>

  Some advanced plugins make use of build contexts as well. For instance, the Ceedling 
  Gcov plugin uses a context of `:gcov`, surprisingly enough. For any plugins with tools
  that take advantage of Ceedling’s internal mechanisms, you can add to those tools'
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
file name criteria. Matchers match on test filenames only, and the specified flags 
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

Flags by matcher are cumulative. This means the flags from multiple matchers can be 
applied to all files processed by the named build operation for any single test executable.

Referencing the example above, here are the extra compilation flags for a handful of 
test executables:

* _test_Something_: `-foo`
* _test_Main_: `-foo -🏴‍☠️`
* _test_Model_: `-foo -Wall -🏴‍☠️`
* _test_CommsSerialModel_: `-foo -Wall -🏴‍☠️ --freak`

The simple `:flags` list format remains available for the `:test` context. Of course, 
this format is limited in that it applies flags to all C files processed by the named
build operation for all test executables.

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

Ceedling sets values for a subset of CMock settings. All CMock options are
available to be set, but only those options set by Ceedling in an automated
fashion are documented below. See CMock documentation.

Ceedling sets values for a subset of CMock settings. All CMock options are
available to be set, but only those options set by Ceedling in an automated
fashion are documented below. See [CMock] documentation.

* `:enforce_strict_ordering`:

  Tests fail if expected call order is not same as source order

  **Default**: TRUE

* `:verbosity`:

  If not set, defaults to Ceedling’s verbosity level

* `:defines`:

  Adds list of symbols used to configure CMock’s C code features in its source and header 
  files at compile time.
  
  See [Using Unity, CMock & CException](#using-unity-cmock--cexception) for much more on
  configuring and making use of these frameworks in your build.
  
  To manage overall command line length, these symbols are only added to compilation when
  a CMock C source file is compiled.
  
  No symbols must be set unless CMock’s defaults are inappropriate for your environment 
  and needs.
  
  **Default**: `[]` (empty)

* `:plugins`:

  To enable CMock’s optional and advanced features available via CMock plugin, simply add 
  `:cmock` ↳ `:plugins` to your configuration and specify your desired additional CMock 
  plugins as a simple list of the plugin names.

  See [CMock's documentation][cmock-docs] to understand plugin options.

  [cmock-docs]: https://github.com/ThrowTheSwitch/CMock/blob/master/docs/CMock_Summary.md

  **Default**: `[]` (empty)

* `:unity_helper_path`:
  
  A Unity helper is a simple header file used by convention to support your specialized
  test case needs. For example, perhaps you want a Unity assertion macro for the 
  contents of a struct used throughout your project. Write the macro you need in a Unity
  helper header file and `#include` that header file in your test file.

  When a Unity helper is provided to CMock, it takes on more significance, and more
  magic happens. CMock parses Unity helper header files and uses macros of a certain
  naming convention to extend CMock’s handling of mocked parameters.

  See the [Unity] and [CMock] documentation for more details.

  `:unity_helper_path` may be a single string or a list. Each value must be a relative
  path from your Ceedling working directory to a Unity helper header file (these are 
  typically organized within containing Ceedling `:paths` ↳ `:support` directories).

  **Default**: `[]` (empty)

* `:includes`:

  In certain advanced testing scenarios, you may need to inject additional header files 
  into generated mocks. The filenames in this list will be transformed into `#include` 
  directives created at the top of every generated mock.

  If `:unity_helper_path` is in use (see preceding), the filenames at the end of any 
  Unity helper file paths will be automatically injected into this list provided to 
  CMock.

  **Default**: `[]` (empty)

### Notes on Ceedling’s nudges for CMock strict ordering

The preceding settings are tied to other Ceedling settings; hence, why they are 
documented here.

The first setting above, `:enforce_strict_ordering`, defaults to `FALSE` within
CMock. However, it is set to `TRUE` by default in Ceedling as our way of
encouraging you to use strict ordering.

Strict ordering is teeny bit more expensive in terms of code generated, test
execution time, and complication in deciphering test failures. However, it’s
good practice. And, of course, you can always disable it by overriding the
value in the Ceedling project configuration file.

## `:unity` Configure Unity’s features

* `:defines`:

  Adds list of symbols used to configure Unity's features in its source and header files
  at compile time.
  
  See [Using Unity, CMock & CException](#using-unity-cmock--cexception) for much more on
  configuring and making use of these frameworks in your build.
  
  To manage overall command line length, these symbols are only added to compilation when
  a Unity C source file is compiled.
  
  **_Note_**: No symbols must be set unless Unity's defaults are inappropriate for your 
  environment and needs.
  
  **Default**: `[]` (empty)

* `:use_param_tests`:

  Configures Unity test runner generation and `#define`s for test compilation to support 
  Unity’s parameterized test cases.

  Example parameterized test case:

  ```C
  TEST_RANGE([5, 100, 5])
  void test_should_handle_divisible_by_5_for_parameterized_test_range(int num) {
    TEST_ASSERT_EQUAL(0, (num % 5));
  }
  ```
  
  See [Unity] documentation for more on parameterized test cases.

  _**Note:**_ Unity’s parameterized tests are incompatible with Ceedling’s preprocessing
  features enabled for test files. See more in [Ceedling’s preprocessing documentation](#preprocessing-gotchas) .
  
  **Default**: false

## `:test_runner` Configure test runner generation

The format of Ceedling test files — the C files that contain unit test cases —
is intentionally simple. It’s pure code and all legit, simple C with `#include`
statements, test case functions, and optional `setUp()` and `tearDown()` 
functions.

To create test executables, we need a `main()` and a variety of calls to the
Unity framework to “hook up” all your test cases into a test suite. You can do
this by hand, of course, but it's tedious and needed updates as code evolves 
are easily forgotten.

So, Unity provides a script able to generate a test runner in C for you. It
relies on [ceedling-conventions] used in your test files. Ceedling takes this 
a step further by calling this script for you with all the needed parameters.

Test runner generation is configurable. The `:test_runner` section of your
Ceedling project file allows you to pass options to Unity’s runner generation
script. Based on other Ceedling options, Ceedling also sets certain test runner 
generation configuration values for you.

[Test runner configuration options are documented in the Unity project][unity-runner-options].

**_Notes:_**

* **Unless you have advanced or unique needs, Unity test runner generation
  configuration in Ceedling is generally not needed.**
* In previous versions of Ceedling, the test runner option
  `:cmdline_args` was needed for certain advanced test suite features. This
  option is still needed, but Ceedling automatically sets it for you in the
  scenarios requiring it. Be aware that this option works well in desktop,
  native testing but is generally unsupported by emulators running test
  executables (the idea of command line arguments passed to an executable is
  generally only possible with desktop command line terminals.)

Example configuration:

```yaml
:test_runner:
  # Insert additional #include statements in a generated runner
  :includes:
    - Foo.h
    - Bar.h
```

[ceedling-conventions]: #important-conventions--behaviors
[unity-runner-options]: https://github.com/ThrowTheSwitch/Unity/blob/master/docs/UnityHelperScriptsGuide.md#options-accepted-by-generate_test_runnerrb

## `:tools` Configuring command line tools used for build steps

Ceedling requires a variety of tools to work its magic. By default, the GNU 
toolchain (`gcc`, `cpp`, `as` — and `gcov` via plugin) are configured and ready 
for use with no additions to your project configuration YAML file.

A few items before we dive in:

1. Sometimes Ceedling’s built-in tools are _nearly_ what you need but not 
   quite. If you only need to add some arguments to all uses of tool's command
   line, Ceedling offers a shortcut to do so. See the 
   [final section of the `:tools`][tool-definition-shortcuts] documentation for 
   details.
1. If you need fine-grained control of the arguments Ceedling uses in the build
   steps for test executables, see the documentation for [`:flags`][flags].
   Ceedling allows you to control the command line arguments for each test 
   executable build — with a variety of pattern matching options.
1. If you need to link libraries — your own or standard options — please see 
   the [top-level `:libraries` section][libraries] available for your 
   configuration file. Ceedling supports a number of useful options for working
   with pre-compiled libraries. If your library linking needs are super simple,
   the shortcut in (1) might be the simplest option.

[flags]: #flags-configure-preprocessing-compilation--linking-command-line-flags
[tool-definition-shortcuts]: #ceedling-tool-modification-shortcuts

### Ceedling tools for test suite builds

Our recommended approach to writing and executing test suites relies on the GNU 
toolchain. _*Yes, even for embedded system work on platforms with their own, 
proprietary C toolchain.*_ Please see 
[this section of documentation][sweet-suite] to understand this recommendation 
among all your options.

You can and sometimes must run a Ceedling test suite in an emulator or on
target, and Ceedling allows you to do this through tool definitions documented
here. Generally, you’ll likely want to rely on the default definitions.

[sweet-suite]: #all-your-sweet-sweet-test-suite-options

### Ceedling tools for release builds

More often than not, release builds require custom tool definitions. The GNU
toolchain is configured for Ceeding release builds by default just as with test
builds. you’ll likely need your own definitions for `:release_compiler`, 
`:release_linker`, and possibly `:release_assembler`.

### Ceedling plugin tools

Ceedling plugins are free to define their own tools that are loaded into your 
project configuration at startup. Plugin tools are defined using the same 
mechanisns as Ceedling’s built-in tools and are called the same way. That is,
all features available to you for working with tools as an end users are
generally available for working with plugin-based tools. This presumes a 
plugin author followed guidance and convention in creating any command line 
actions.

### Ceedling tool definitions

Contained in this section are details on Ceedling’s default tool definitions.
For sake of space, the entirety of a given definition is not shown. If you need
to get in the weeds or want a full example, see the file `defaults.rb` in 
Ceedling’s lib/ directory.

#### Tool definition overview

Listed below are the built-in tool names, corresponding to build steps along 
with the numbered parameters that Ceedling uses to fill out a full command line
for the named tool. The full list of fundamental elements for a tool definition
are documented in the sections that follow along with examples.

Not every numbered parameter listed immediately below must be referenced in a
Ceedling tool definition. If `${4}` isn’t referenced by your custom tool, 
Ceedling simply skips it while expanding a tool definition into a command line.

The numbered parameters below are references that expand / are replaced with 
actual values when the corresponding command line is constructed. If the values
behind these parameters are lists, Ceedling expands the containing reference
multiple times with the contents of the value. A conceptual example is 
instructive…

#### Simplified tool definition / expansion example

A partial tool definition:

```yaml
:tools:
   :power_drill:
      :executable: dewalt.exe
      :arguments:
         - "--X${3}"
```

Let's say that `${3}` is a list inside Ceedling, `[2, 3, 7]`. The expanded tool
command line for `:tools` ↳ `:power_drill` would look like this:

```shell
 > dewalt.exe --X2 --X3 --X7
```

#### Ceedling’s default build step tool definitions

**_NOTE:_** Ceedling’s tool definitions for its preprocessing and backtrace 
features are not documented here. Ceedling’s use of tools for these features
are tightly coupled to the options and output of those tools. Drop-in 
replacements using other tools are not practically possible. Eventually, an
improved plugin system will provide options for integrating alternative tools.

* `:test_compiler`:

  Compiler for test & source-under-test code

   - `${1}`: Input source
   - `${2}`: Output object
   - `${3}`: Optional output list
   - `${4}`: Optional output dependencies file
   - `${5}`: Header file search paths
   - `${6}`: Command line #defines

  **Default**: `gcc`

* `:test_assembler`:

  Assembler for test assembly code

   - `${1}`: input assembly source file
   - `${2}`: output object file
   - `${3}`: search paths
   - `${4}`: #define symbols (accepted but ignored by GNU assembler)

  **Default**: `as`

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
   - `${3}`: search paths
   - `${4}`: #define symbols (accepted but ignored by GNU assembler)

  **Default**: `as`

* `:release_linker`:

  Linker for release source code

   - `${1}`: input objects
   - `${2}`: output binary
   - `${3}`: optional output map
   - `${4}`: optional library list
   - `${5}`: optional library path list

  **Default**: `gcc`

#### Tool defintion configurable elements

1. `:executable` - Command line executable (required).

    NOTE: If an executable contains a space (e.g. `Code Cruncher`), and the 
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
   then Ceedling will form a name from the tool's YAML entry key.

1. `:stderr_redirect` - Control of capturing `$stderr` messages
   {`:none`, `:auto`, `:win`, `:unix`, `:tcsh`}.
   Defaults to `:none` if unspecified. You may create a custom entry by
   specifying a simple string instead of any of the recognized
   symbols. As an example, the `:unix` symbol maps to the string `2>&1`
   that is automatically inserted at the end of a command line.

   This option is rarely necessary. `$stderr` redirection was originally 
   often needed in early versions of Ceedling. Shell output stream handling
   is now automatically handled. This option is preserved for possible edge 
   cases.

1. `:optional` - By default a tool you define is required for operation. This
   means a build will be aborted if Ceedling cannot find your tool’s executable 
   in your  environment. However, setting `:optional` to `true` causes this 
   check to be skipped. This is most often needed in plugin scenarios where a 
   tool is only needed if an accompanying configuration option requires it. In 
   such cases, a programmatic option available in plugin Ruby code using the
   Ceedling class `ToolValidator` exists to process tool definitions as needed.

#### Tool element runtime substitution

To accomplish useful work on multiple files, a configured tool will most often
require that some number of its arguments or even the executable itself change
for each run. Consequently, every tool’s argument list and executable field
possess two means for substitution at runtime.

Ceedling provides inline Ruby string expansion and a notation for populating 
tool elements with dynamically gathered values within the build environment.

##### Tool element runtime substitution: Inline Ruby string expansion

`"#{...}"`: This notation is that of the beloved 
[inline Ruby string expansion][inline-ruby-string-expansion] available in a 
variety of configuration file sections. This string expansion occurs each 
time a tool configuration is executed during a build.

##### Tool element runtime substitution: Notational substitution

A Ceedling tool's other form of dynamic substitution relies on a `$` notation.
These `$` operators can exist anywhere in a string and can be decorated in any
way needed. To use a literal `$`, escape it as `\\$`.

* `$`: Simple substitution for value(s) globally available within the runtime
  (most often a string or an array).

* `${#}`: When a Ceedling tool's command line is expanded from its configured
  representation, runs of that tool will be made with a parameter list of
  substitution values. Each numbered substitution corresponds to a position in
  a parameter list.

   * In the case of a compiler `${1}` will be a C code file path, and `$
     {2}` will be the file path of the resulting object file.

   * For a linker `${1}` will be an array of object files to link, and `$
     {2}` will be the resulting binary executable.

   * For an executable test fixture `${1}` is either the binary executable
     itself (when using a local toolchain such as GCC) or a binary input file
     given to a simulator in its arguments.

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
  as preprocessing features are quite dependent on the 
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
1. We’re using `$stderr` redirection to allow us to capture simulator error 
   messages to `$stdout` for display at the run's conclusion.

### Ceedling tool modification shortcuts

Sometimes Ceedling’s default tool defininitions are _this close_ to being just
what you need. But, darn, you need one extra argument on the command line, or
you just need to hack the tool executable. You’d love to get away without 
overriding an entire tool definition just in order to tweak it.

We got you.

#### Ceedling tool executable replacement

Sometimes you need to do some sneaky stuff. We get it. This feature lets you
replace the executable of a tool definition — including an internal default —
with your own.

To use this shortcut, simply add a configuration section to your project file at
the top-level, `:tools_<tool_to_modify>` ↳ `:executable`. Of course, you can
combine this with the following modification option in a single block for the
tool. Executable replacement can make use of 
[inline Ruby string expansion][inline-ruby-string-expansion].

See the list of tool names at the beginning of the `:tools` documentation to
identify the named options. Plugins can also include their own tool definitions
that can be modified with this same option.

This example YAML...

```yaml
:tools_test_compiler:
   :executable: foo
```

... will produce the following:

```shell
 > foo <Ceedling default command line>
```

#### Ceedling tool arguments addition shortcut

Now, this little feature only allows you to add arguments to the end of a tool
command line. Not the beginning. And, you can’t remove arguments with this
option.

Further, this little feature is a blanket application across all uses of a tool.
If you need fine-grained control of command line flags in build steps per test
executable, please see the [`:flags` configuration documentation][flags].

To use this shortcut, simply add a configuration section to your project file at
the top-level, `:tools_<tool_to_modify>` ↳ `:arguments`. Of course, you can
combine this with the preceding modification option in a single block for the
tool.

See the list of tool names at the beginning of the `:tools` documentation to
identify the named options. Plugins can also include their own tool definitions
that can be modified with this same hack.

This example YAML...

```yaml
:tools_test_compiler:
   :arguments:
      - --flag # Add `--flag` to the end of all test C file compilation
```

... will produce the following (for the default executable):

```shell
 > gcc <Ceedling default command line> --flag
```

## `:plugins` Ceedling extensions

See the section below dedicated to plugins for more information. This section
pertains to enabling plugins in your project configuration.

Ceedling includes a number of built-in plugins. See the collection within
the project at [plugins/][ceedling-plugins] or the [documentation section below](#ceedling-plugins)
dedicated to Ceedling’s plugins. Each built-in plugin subdirectory includes 
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

# Which Ceedling

In certain scenarios you may need to run a different version of Ceedling.
Typically, Ceedling developers need this ability. But, it could come in
handy in certain advanced Continuous Integration build scenarios or some
sort of version behavior comparison.

It’s not uncommon in Ceedling development work to have the last production 
gem installed while modifying the application code in a locally cloned 
repository. Or, you may be bouncing between local versions of Ceedling to
troubleshoot changes.

Which Ceedling handling gives you options on what gets run.

## Which Ceedling background

Ceedling is usually packaged and installed as a Ruby Gem. This gem ends
up installed in an appropriate place by the `gem` package installer.
Inside the gem installation is the entire Ceedling project. The `ceedling`
command line launcher lives in `bin/` while the Ceedling application lives
in `lib/`. The code in `/bin` manages lots of startup details and base
configuration. Ultimately, it then launches the main application code from
`lib/`.

The features and conventions controlling _which ceedling_ dictate which
application code the `ceedling` command line handler launches.

_NOTE:_ If you are a developer working on the code in Ceedling’s `bin/` 
and want to run it while a gem is installed, you must take the additional 
step of specifying the path to the `ceedling` launcher in your file system.

In Unix-like systems, this will look like:
`> my/ceedling/changes/bin/ceedling <args>`.

On Windows systems, you may need to run:
`> ruby my\ceedling\changes\bin\ceedling <args>`.

## Which Ceedling options and precedence

When Ceedling starts up, it evaluates a handful of conditions to determine
which Ceedling location to launch.

The following are evaluated in order:

1. Environment variable `WHICH_CEEDLING`. If this environment variable is
   set, its value is used.
1. Configuration entry `:project` ↳ `:which_ceedling`. If this is set,
   its value is used.
1. The path `vendor/ceedling`. If this path exists in your working 
   directory — typically because of a `--local` vendored installation at
   project creation — its contents are used to launch Ceedling.
1. If none of the above exist, the `ceedling` launcher defaults to using
   the `lib/` directory next to the `bin/` directory from which the 
   `ceedling` launcher is running. In the typical case this is the default 
   gem installation.

_NOTE:_ Configuration entry (2) does not make sense in some scenarios.
When running `ceedling new`, `ceedling examples`, or `ceedling example` 
there is no project file to read. Similarly, `ceedling upgrade` does not 
load a project file; it merely works with the directory structure and 
contets of a project. In these cases, the environment variable is your
only option to set which Ceedling to launch.

## Which Ceedling settings

The environment variable and configuration entry for _Which Ceedling_ can
contain two values:

1. The value `gem` indicates that the command line `ceedling` launcher 
   should run the application packaged alongside it in `lib/` (these 
   paths are typically found in the gem installation location).
1. A relative or absolute path in your file system. Such a path should 
   point to the top-level directory that contains Ceedling’s `bin/` and 
   `lib/` sub-directories.

<br/>

# Build Directive Macros

## Overview of Build Directive Macros

Ceedling supports a small number of build directive macros. At present,
these macros are only for use in test files.

By placing these macros in your test files, you may control aspects of an 
individual test executable's build from within the test file itself.

These macros are actually defined in Unity, but they evaluate to empty 
strings. That is, the macros do nothing and only serve as text markers for 
Ceedling to parse. But, by placing them in your test files they 
communicate instructions to Ceedling when scanned at the beginning of a 
test build.

**_Notes:_**

- Since these macros are defined in _unity.h_, it’s essential to 
  `#include "unity.h"` before making use of them in your test file. 
  Typically, _unity.h_ is referenced at or near the top of a test file
  anyhow, but this is an important detail to call out.
- **`TEST_SOURCE_FILE()` and `TEST_INCLUDE_PATH()`, new in Ceedling 
  1.0.0, are incompatible with enclosing conditional compilation C 
  preprocessing statements.** See
  [Ceedling’s preprocessing documentation](#preprocessing-gotchas) 
  for more details.

## `TEST_SOURCE_FILE()`

### `TEST_SOURCE_FILE()` Purpose

The `TEST_SOURCE_FILE()` build directive allows the simple injection of 
a specific source file into a test executable’s build.

The Ceedling [convention][ceedling-conventions] of compiling and linking 
any C file that corresponds in name to an `#include`d header file does 
not always work. A given source file may not have a header file that 
corresponds directly to its name. In some specialized cases, a source 
file may not rely on a header file at all.

Attempting to `#include` a needed C source file directly is both ugly and
can cause various build problems with duplicated symbols, etc.

`TEST_SOURCE_FILE()` is the way to cleanly and simply add a given C file
to the executable built from a test file. `TEST_SOURCE_FILE()` is also one 
of the best methods for adding an assembly file to the build of a given 
test executable—if assembly support is enabled for test builds.

### `TEST_SOURCE_FILE()` Usage

The argument for the `TEST_SOURCE_FILE()` build directive macro is a 
single filename or filepath as a string enclosed in quotation marks. Use
forward slashes for path separators. The filename or filepath must be 
present within Ceedling’s source file collection.

To understand your source file collection:

- See the documentation for project file configuration section 
  [`:paths`](#project-paths-configuration).
- Dump a listing your project’s source files with the command line task
  `ceedling files:source`.

Multiple uses of `TEST_SOURCE_FILE()` are perfectly fine. You’ll likely
want one per line within your test file.

### `TEST_SOURCE_FILE()` Example

```c
/*
 * Test file test_mycode.c to exercise functions in mycode.c.
 */
 
#include "unity.h"    // Contains TEST_SOURCE_FILE() definition
#include "support.h"  // Needed symbols and macros
//#include "mycode.h" // Header file corresponding to mycode.c by convention does not exist

// Tell Ceedling to compile and link mycode.c as part of the test_mycode executable
TEST_SOURCE_FILE("foo/bar/mycode.c")

// --- Unit test framework calls ---

void setUp(void) {
  ...
}

void test_MyCode_FooBar(void) {
  ...
}
```

## `TEST_INCLUDE_PATH()`

### `TEST_INCLUDE_PATH()` Purpose

The `TEST_INCLUDE_PATH()` build directive allows a header search path to
be injected into the build of an individual test executable.

Unless you have a pretty funky C project, generally at least one search path entry
is necessary for every test executable build. That path can come from a `:paths`  
↳ `:include` entry in your project configuration or by using `TEST_INCLUDE_PATH()` 
in a test file.

Please see [Configuring Your Header File Search Paths][header-file-search-paths]
for an overview of Ceedling’s options and conventions for header file search paths.

### `TEST_INCLUDE_PATH()` Usage

`TEST_INCLUDE_PATH()` entries in your test file are only an additive customization.
The path will be added to the base / common path list specified by 
`:paths`  ↳ `:include` in the project file. If no list is specified in your project 
configuration, `TEST_INCLUDE_PATH()` entries will comprise the entire header search 
path list.

The argument for the `TEST_INCLUDE_PATH()` build directive macro is a single 
filepath as a string enclosed in quotation marks. Use forward slashes for 
path separators.

**_Note_**: At present, a limitation of the `TEST_INCLUDE_PATH()` build directive 
macro is that paths are relative to the working directory from which you are 
executing `ceedling`. A change to your working directory could require updates to 
the path arguments of dall instances of `TEST_INCLUDE_PATH()`.

Multiple uses of `TEST_INCLUDE_PATH()` are perfectly fine. You’ll likely want one 
per line within your test file.

[header-file-search-paths]: #configuring-your-header-file-search-paths

### `TEST_INCLUDE_PATH()` Example

```c
/*
 * Test file test_mycode.c to exercise functions in mycode.c.
 */

#include "unity.h"    // Contains TEST_INCLUDE_PATH() definition
#include "somefile.h" // Needed symbols and macros

// Add the following to the compiler's -I search paths used to
// compile all components comprising the test_mycode executable.
TEST_INCLUDE_PATH("foo/bar/")
TEST_INCLUDE_PATH("/usr/local/include/baz/")

// --- Unit test framework calls ---

void setUp(void) {
  ...
}

void test_MyCode_FooBar(void) {
  ...
}
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

## Ceedling’s built-in plugins, a directory

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

[This plugin][command-hooks] provides a simple means for connecting Ceedling’s build events to
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
syntax highlighting, etc. by way of the LLVM project’s [`clangd`][clangd] 
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
