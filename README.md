# Ceedling ![CI](https://github.com/ThrowTheSwitch/Ceedling/workflows/CI/badge.svg)

🚚 _February 16, 2024_ || **Ceedling 0.32** is a release candidate and will be shipping very soon. See the [Release Notes](#docs/ReleaseNotes.md).

# 🌱 Ceedling is a handy-dandy build system for C projects

## Developer-friendly release _and_ test builds

**Ceedling can build your release artifact but is especially adept at building
test suites.**

Ceedling works the way developers want to work. It is flexible and entirely
command-line driven. It drives code generation and command line tools for you.
All generated and framework code is easy to see and understand.

Ceedling's features support low-level embedded development to enterprise-level software 
systems.

🚀 Eager to just get going? Jump to [📚 Documentation & Learning](#-documentation--learning) and
[⭐️ Getting Started](#-getting-started).

## Ceedling is a suite of tools

Ceedling is also a suite of tools. It is the glue for bringing together three 
other awesome open-source projects you can’t live without if you‘re creating 
awesomeness in the C language.

1. **[Unity]**, an xUnit-style test framework.
1. **[CMock]**<sup>†</sup>, a code generating, 
   [function mocking & stubbing][test-doubles] kit for interaction-based testing.
1. **[CException]**, a framework for adding simple exception handling to C projects
   in the style of higher-order programming languages.

<sup>†</sup> Through a [plugin][FFF-plugin], Ceedling also supports [FFF] for 
[fake functions][test-doubles] as an alternative to CMock’s mocks and stubs.

## But, wait. There’s more.

For simple project structures, Ceedling can build and test an entire project from just a
few lines in its project configuration file.

Because it handles all the nitty-gritty of rebuilds and becuase of Unity and CMock,
Ceedling makes [Test-Driven Development][TDD] in C a breeze.

Ceedling is also extensible with a simple plugin mechanism. It comes with a number of built-in plugins for code coverage, test suite report generation, Continuous Integration features, IDE integration, release library builds & dependency management, and more.

[Unity]: https://github.com/throwtheswitch/unity
[CMock]: https://github.com/throwtheswitch/cmock
[CException]: https://github.com/throwtheswitch/cexception
[TDD]: http://en.wikipedia.org/wiki/Test-driven_development
[test-doubles]: https://blog.pragmatists.com/test-doubles-fakes-mocks-and-stubs-1a7491dfa3da
[FFF]: https://github.com/meekrosoft/fff
[FFF-plugin]: https://github.com/ElectronVector/fake_function_framework

<br/>

# 🧑‍🍳 Sample Unit Testing Code

While Ceedling can build your release artifact, its claim to fame is building and running tests suites.

There’s a good chance you’re looking at Ceedling because of its test suite abilities. And, you’d probably like to see what that looks like, huh? Well, let’s cook you up some realistic examples of tested code and running Ceedling with that code.

## First, we start with a serving of source code to be tested…

Tastes of two source files follow.

### Recipe.c

```c
#include "Recipe.h"
#include "Kitchen.h"
#include <stdio.h>

#define MAX_SPICE_COUNT (4)
#define MAX_SPICE_AMOUNT_TSP (8.0f)

static float spice_amount = 0;
static uint8_t spice_count = 0;

void Recipe_Reset(char* recipe, size_t size) {
  memset(recipe, 0, size);
  spice_amount = 0;
  spice_count = 0;
}

// Add ingredients to a spice list string with amounts (tsp.)
bool_t Recipe_BuildSpiceListTsp(char* list, size_t maxLen, SpiceId spice, float amount) {
  if ((++spice_count > MAX_SPICE_COUNT) || ((spice_amount += amount) > MAX_SPICE_AMOUNT_TSP)) {
    snprintf( list, maxLen, "Too spicy!" );
    return FALSE;
  }

  // Kitchen_Ingredient() not shown
  snprintf( list + strlen(list), maxLen, "%s\n", Kitchen_Ingredient( spice, amount, TEASPOON ) );
  return TRUE;
}
```

### Baking.c

```c
#include "Oven.h"
#include "Time.h"
#include "Baking.h"

bool_t Baking_PreheatOven(float setTempF, duration_t timeout) {
  float temperature = 0.0;
  Timer* timer = Time_StartTimer( timeout );
  
  Oven_SetTemperatureF( setTempF );

  while (temperature < setTempF) {
    Time_SleepMs( 250 );
    if (Time_IsTimerExpired( timer )) break;
    temperature = Oven_GetTemperatureReadingF();
  }

  return (temperature >= setTempF);
}

```

## Next, a sprinkle of unit test code…

Some of what Ceedling does is by naming conventions. See Ceedling’s [documentation](#-documentation--learning) for much more on this.

### TestRecipe.c

```c
#include "unity.h"   // Unity, unit test framework
#include "Recipe.h"  // By convention, Recipe.c is part of TestRecipe executable build
#include "Kitchen.h" // By convention, Kitchen.c (not shown) is part of TestRecipe executable build

char recipe[100];

void setUp(void) {
  // Execute reset before each test case
  Recipe_Reset( recipe, sizeof(recipe) );
}

void test_Recipe_BuildSpiceListTsp_shouldBuildSpiceList(void) {
  TEST_ASSERT_TRUE( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), OREGANO, 0.5 ) );
  TEST_ASSERT_TRUE( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), ROSEMARY, 1.0 ) );
  TEST_ASSERT_TRUE( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), THYME, 0.33 ) );
  TEST_ASSERT_EQUAL_STRING( "1/2 tsp. Oregano\n1 tsp. Rosemary\n1/3 tsp. Thyme\n", recipe );
}

void test_Recipe_BuildSpiceListTsp_shouldFailIfTooMuchSpice(void) {
  TEST_ASSERT_TRUE ( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), CORIANDER, 4.0 ) );
  TEST_ASSERT_TRUE ( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), BLACK_PEPPER, 4.0 ) );
  // Total spice = 8.0 + 0.1 tsp.
  TEST_ASSERT_FALSE( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), BASIL, 0.1 ) );
  TEST_ASSERT_EQUAL_STRING( "Too spicy!", recipe );
}

void test_Recipe_BuildSpiceListTsp_shouldFailIfTooManySpices(void) {
  TEST_ASSERT_TRUE ( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), OREGANO, 1.0 ) );
  TEST_ASSERT_TRUE ( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), CORIANDER, 1.0 ) );
  TEST_ASSERT_TRUE ( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), BLACK_PEPPER, 1.0 ) );
  TEST_ASSERT_TRUE ( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), THYME, 1.0 ) );
  // Attempt to add 5th spice
  TEST_ASSERT_FALSE( Recipe_BuildSpiceListTsp( recipe, sizeof(recipe), BASIL, 1.0 ) );
  TEST_ASSERT_EQUAL_STRING( "Too spicy!", recipe );
}
```

### TestBaking.c

Let’s flavor our test code with a dash of mocks as well…

```c
#include "unity.h"    // Unity, unit test framework
#include "Baking.h"   // By convention, Baking.c is part of TestBaking executable build
#include "MockOven.h" // By convention, mock .h/.c code generated from Oven.h by CMock
#include "MockTime.h" // By convention, mock .h/.c code generated from Time.h by CMock

/*
 * 🚫 This test will fail! Find the missing logic in `Baking_PreheatOven()`.
 * (`Oven_SetTemperatureF()` returns success / failure.)
 */
void test_Baking_PreheatOven_shouldFailIfSettingOvenTemperatureFails(void) {
  Timer timer; // Uninitialized struct

  Time_StartTimer_ExpectAndReturn( TWENTY_MIN, &timer );

  // Tell source code that setting the oven temperature did not work
  Oven_SetTemperatureF_ExpectAndReturn( 350.0, FALSE );

  TEST_ASSERT_FALSE( Baking_PreheatOven( 350.0, TWENTY_MIN ) );
}

void test_Baking_PreheatOven_shouldFailIfTimeoutExpires(void) {
  Timer timer; // Uninitialized struct

  Time_StartTimer_ExpectAndReturn( TEN_MIN, &timer );

  Oven_SetTemperatureF_ExpectAndReturn( 200.0, TRUE );

  // We only care that `sleep()` is called, not necessarily every call to it
  Time_SleepMs_Ignore();

  // Unrolled loop of timeout and temperature checks
  Time_IsTimerExpired_ExpectAndReturn( &timer, FALSE );
  Oven_GetTemperatureReadingF_ExpectAndReturn( 100.0 );
  Time_IsTimerExpired_ExpectAndReturn( &timer, FALSE );
  Oven_GetTemperatureReadingF_ExpectAndReturn( 105.0 );
  Time_IsTimerExpired_ExpectAndReturn( &timer, FALSE );
  Oven_GetTemperatureReadingF_ExpectAndReturn( 110.0 );
  Time_IsTimerExpired_ExpectAndReturn( &timer, TRUE );

  TEST_ASSERT_FALSE( Baking_PreheatOven( 200.0, TEN_MIN ) );  
}

void test_Baking_PreheatOven_shouldSucceedAfterAWhile(void) {
  Timer timer; // Uninitialized struct

  Time_StartTimer_ExpectAndReturn( TEN_MIN, &timer );

  Oven_SetTemperatureF_ExpectAndReturn( 400.0, TRUE );

  // We only care that `sleep()` is called, not necessarily every call to it
  Time_SleepMs_Ignore();

  // Unrolled loop of timeout and temperature checks
  Time_IsTimerExpired_ExpectAndReturn( &timer, FALSE );
  Oven_GetTemperatureReadingF_ExpectAndReturn( 390.0 );
  Time_IsTimerExpired_ExpectAndReturn( &timer, FALSE );
  Oven_GetTemperatureReadingF_ExpectAndReturn( 395.0 );
  Time_IsTimerExpired_ExpectAndReturn( &timer, FALSE );
  Oven_GetTemperatureReadingF_ExpectAndReturn( 399.0 );
  Time_IsTimerExpired_ExpectAndReturn( &timer, FALSE );
  Oven_GetTemperatureReadingF_ExpectAndReturn( 401.0 );

  TEST_ASSERT_TRUE( Baking_PreheatOven( 400.0, TEN_MIN ) );
}
```

## Add a pinch of command line…

See Ceedling’s [documentation](#-documentation--learning) for examples and everything you need to know about Ceedling’s configuration file options (not shown here).

The super duper short version is that your project configuration file tells Ceedling where to find test and source files, what testing options you’re using, sets compilation symbols and build tool flags, enables your plugins, and configures your build tool command lines (Ceedling defaults to using the GNU compiler collection — which must be installed, if used).

```shell
 > ceedling test:all
```

## Voilà! Test results. `#ChefsKiss`

The test results below are one of the last bits of logging Ceedling produces for a test suite build. Not shown here are all the steps for extracting build details, C code generation, and compilation and linking.

```
-------------------
FAILED TEST SUMMARY
-------------------
[test/TestBaking.c]
  Test: test_Baking_PreheatOven_shouldFailIfSettingOvenTemperatureFails
  At line (7): "Function Time_SleepMs() called more times than expected."

--------------------
OVERALL TEST SUMMARY
--------------------
TESTED:  6
PASSED:  5
FAILED:  1
IGNORED: 0
```

<br/>

# 📚 Documentation & Learning

## Ceedling docs

**[Usage help][ceedling-packet]** (a.k.a. _Ceedling Packet_), **[release notes][release-notes]**, **[breaking changes][breaking-changes]**, a variety of guides, and much more exists in **[docs/](docs/)**.

## Library and courses

[ThrowTheSwitch.org][TTS]:

* Provides a small but useful **[library of resources and guides][library]** on testing and using the Ceedling suite of tools.
* Discusses your **[options for running a test suite][running-options]**, particularly in the context of embedded systems.
* Links to paid courses, **_[Dr. Surly’s School for Mad Scientists][courses]_**, that provide in-depth training on creating C unit tests and using Unity, CMock, and Ceedling to do so.

## Online tutorial

Matt Chernosky’s **[detailed tutorial][tutorial]** demonstrates using Ceedling to build a C project with test suite. As the tutorial is a number of years old, the content is a bit out of date. That said, it provides an excellent overview of a real project.

[ceedling-packet]: docs/CeedlingPacket.md
[release-notes]: docs/ReleaseNotes.md
[breaking-changes]: docs/BreakingChanges.md
[TTS]: https://throwtheswitch.org
[library]: http://www.throwtheswitch.org/library
[running-options]: http://www.throwtheswitch.org/build/which
[courses]: http://www.throwtheswitch.org/dr-surlys-school
[tutorial]: http://www.electronvector.com/blog/add-unit-tests-to-your-current-project-with-ceedling

<br/>

# ⭐️ Getting Started

👀 See the **_[Quick Start](docs/CeedlingPacket.md#quick-start)_** section in Ceedling’s core documentation, _Ceedling Packet_.

## The basics

### Local installation

1. Install [Ruby]. (Only Ruby 3+ supported.)
1. Install Ceedling. (All supporting frameworks are included.)
   ```shell
   > gem install ceedling
   ```
1. Create an empty Ceedling project or add a Ceedling project file to
   the root of your existing project.
1. Run tasks like so:
   ```shell
   > ceedling test:all release
   ```

### Docker image

A fully packaged [Ceedling Docker image][docker-image] containing Ruby, Ceedling, the GCC toolchain, and some helper scripts is also available. A Docker container is a self-contained, portable, well managed alternative to a local installation of Ceedling.

The Ceedling Docker image is early in its lifecycle and due for significant updates and improvements. Check its documentation for version information, status, and supported platforms.

[docker-image]: https://hub.docker.com/r/throwtheswitch/madsciencelab

### Example super-duper simple Ceedling configuration file

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

[Ruby]: https://www.ruby-lang.org/

## Creating a project

Creating a project with Ceedling is easy. Simply tell Ceedling the
name of the project, and it will create a directory with that name
and fill it with a default subdirectory structure and configuration 
file.

```shell
 > ceedling new YourNewProjectName
```

You can add files to your `src/` and `test/` directories, and they will
instantly become part of your test build. Need a different structure?
You can modify the `project.yml` file with your new path or tooling 
setup.

You can upgrade to the latest version of Ceedling at any time,
automatically gaining access to any updates to Unity, CMock, and 
CException that come with it.

```shell
 > gem update ceedling
```

## Installing local documentation

Are you just getting started with Ceedling? Maybe you'd like your
project to be installed with some of its handy [documentation](docs/)? 
No problem! You can do this when you create a new project.

```shell
 > ceedling new --docs MyAwesomeProject
```

## Attaching a Ceedling version to your project

Ceedling can be installed as a globally available Ruby gem. Ceedling can 
also deploy all of its guts into your project instead. This allows it to 
be used without worrying about external dependencies. More importantly, 
you don’t have to worry about Ceedling changing outside of your project 
just because you updated your gems. No need to worry about changes in 
Unity or CMock breaking your build in the future.

To use Ceedling this way, tell it you want a local copy when you create
your project:

```shell
 > ceedling new --local YourNewProjectName
```

This will install all of Unity, CMock, CException, and Ceedling itsef 
into a new folder `vendor/` inside your project `YourNewProjectName/`.
It will still create a simple empty directory structure for you with
`src/` and `test/` folders.

If you want to force a locally installed version of Ceedling to upgrade
to match your latest gem later, no problem. Just do the following:

```shell
 > ceedling upgrade --local YourNewProjectName
```

Just like with the `new` command, an `upgrade` should be executed from 
from within the root directory of your project.

Are you afraid of losing all your local changes when this happens? You 
can prevent Ceedling from updating your project file by adding 
`--no_configs`.

```shell
 > ceedling upgrade --local --no_configs YourSweetProject
```

## Git integration

Are you using Git? You might want Ceedling to create a `.gitignore` 
file for you by adding `--gitignore` to your `new` call.

```shell
 > ceedling new --gitignore YourNewProjectName
```
<br/>

# 💻 Contributin to Ceedling Development

## Alternate installation

```shell
 > git clone --recursive https://github.com/throwtheswitch/ceedling.git
 > cd ceedling
 > git submodule update --init --recursive
 > bundle install
```

The Ceedling repository incorporates its supporting frameworks and some
plugins via git submodules. A simple clone may not pull in the latest
and greatest.

The `bundle` tool ensures you have all needed Ruby gems installed. If 
Bundler isn’t installed on your system or you run into problems, you 
might have to install it:

```shell
 > sudo gem install bundler
```

If you run into trouble running bundler and get messages like _can’t 
find gem bundler (>= 0.a) with executable bundle 
(Gem::GemNotFoundException)_, you may need to install a different 
version of Bundler. For this please reference the version in the 
Gemfile.lock.

```shell
 > sudo gem install bundler -v <version in Gemfile.lock>
```

## Running self-tests

Ceedling uses [RSpec] for its tests.

To run all tests run the following from the root of your local 
Ceedling repository.

```shell
 > bundle exec rake
```

To run individual test files and perform other tasks, use the 
available Rake tasks. From the root of your local Ceedling repo,
list those task like this:

```shell
 > rake -T
```

[RSpec]: https://rspec.info