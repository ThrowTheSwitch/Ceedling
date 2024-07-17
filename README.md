# Ceedling ![CI](https://github.com/ThrowTheSwitch/Ceedling/workflows/CI/badge.svg)

_July 11, 2024_ 🚚 **Ceedling 1.0.0** is a release candidate and will be
shipping very soon. See the [Release Notes](docs/ReleaseNotes.md) for an overview
of all that’s new since 0.31.1 plus links to the detailed Changelog and list of 
Breaking Changes.

# 🌱 Ceedling is a handy-dandy build system for C projects

## Developer-friendly release _and_ test builds

Ceedling can build your release artifact but is especially adept at building
unit test suites for your C projects — even in tricky embedded systems.

Ceedling and its complementary pieces and parts are and always will be freely
available and open source. **_[Ceedling Pro][ceedling-pro]_** is a growing list 
of paid products and services to help you do even more with these tools.

[ceedling-pro]: https://thingamabyte.com/ceedlingpro

⭐️ **Eager to just get going? Jump to 
[📚 Documentation & Learning](#-documentation--learning) and
[🚀 Getting Started](#-getting-started).**

Ceedling works the way developers want to work. It is flexible and entirely
command-line driven. It drives code generation and command line tools for you.
All generated and framework code is easy to see and understand.

Ceedling’s features support all types of C development from low-level embedded
to enterprise systems. No tool is perfect, but Ceedling can do a whole lot to 
help you and your team produce quality software.

## Ceedling is a suite of tools

Ceedling is also a suite of tools. It is the glue for bringing together three 
other awesome open-source projects you can’t live without if you‘re creating 
awesomeness in the C language.

1. **[Unity]**, an [xUnit]-style test framework.
1. **[CMock]**<sup>†</sup>, a code generating, 
   [function mocking & stubbing][test-doubles] kit for interaction-based testing.
1. **[CException]**, a framework for adding simple exception handling to C projects
   in the style of higher-order programming languages.

<sup>†</sup> Through a [plugin][FFF-plugin], Ceedling also supports [FFF] for 
[fake functions][test-doubles] as an alternative to CMock’s mocks and stubs.

## But, wait. There’s more.

For simple project structures, Ceedling can build and test an entire project
from just a few lines in its project configuration file.

Because it handles all the nitty-gritty of rebuilds and becuase of Unity and
CMock, Ceedling makes [Test-Driven Development][TDD] in C a breeze. It even 
provides handy backtrace debugging options for finding the source of crashing
code exercised by your unit tests.

Ceedling is extensible with a simple plugin mechanism. It comes with a
number of [built-in plugins][ceedling-plugins] for code coverage, test suite
report generation, Continuous Integration features, IDE integration, release
library builds & dependency management, and more.

[Unity]: https://github.com/throwtheswitch/unity
[xUnit]: https://en.wikipedia.org/wiki/XUnit
[CMock]: https://github.com/throwtheswitch/cmock
[CException]: https://github.com/throwtheswitch/cexception
[TDD]: http://en.wikipedia.org/wiki/Test-driven_development
[test-doubles]: https://blog.pragmatists.com/test-doubles-fakes-mocks-and-stubs-1a7491dfa3da
[FFF]: https://github.com/meekrosoft/fff
[FFF-plugin]: plugins/fff
[ceedling-plugins]: docs/CeedlingPacket.md#ceedling-plugins

<br/>

# 🙋‍♀️ Need Help? Want to Help?

* Found a bug or want to suggest a feature?
  **[Submit an issue][ceedling-issues]** at this repo.
* Trying to understand features or solve a testing problem? Hit the
  **[discussion forums][forums]**.
* Paid training, customizations, and support contracts are available through 
  **[Ceedling Pro][ceedling-pro]**.

The ThrowTheSwitch community follows a **[code of conduct](docs/CODE_OF_CONDUCT.md)**.

Please familiarize yourself with our guidelines for **[contributing](docs/CONTRIBUTING.md)** to this project, be it code, reviews, documentation, or reports.

Yes, work has begun on certified versions of the Ceedling suite of tools to be available through **[Ceedling Pro][ceedling-pro]**. [Reach out to ThingamaByte][thingama-contact] for more.

[ceedling-issues]: https://github.com/ThrowTheSwitch/Ceedling/issues
[forums]: https://www.throwtheswitch.org/forums
[thingama-contact]: https://www.thingamabyte.com/contact

<br/>

# 🧑‍🍳 Sample Unit Testing Code

While Ceedling can build your release artifact, its claim to fame is building and running tests suites.

There’s a good chance you’re looking at Ceedling because of its test suite abilities. And, you’d probably like to see what that looks like, huh? Well, let’s cook you up some realistic examples of tested code and running Ceedling with that code.

(A sample Ceedling project configuration file and links to documentation for it are a bit further down.)

## First, we start with servings of source code to be tested…

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

-----------------------
❌ OVERALL TEST SUMMARY
-----------------------
TESTED:  6
PASSED:  5
FAILED:  1
IGNORED: 0
```

## Ceedling also supports various side dishes in your delicious test suite

The Unity project supports parameterized test cases like this:

```C
TEST_RANGE([5, 100, 5])
void test_should_handle_divisible_by_5_for_parameterized_test_range(int num) {
  TEST_ASSERT_EQUAL(0, (num % 5));
}
```

Ceedling can do all the magic to build and run this test code simply by enabling parameterized test cases in its project configuration. Keep reading for more on how to configure a Ceedling build.

```yaml
:unity:
  :use_param_tests: TRUE
```

<br/>

# 📚 Documentation & Learning

A variety of options for [community-based support][TTS-help] exist.

Training and support contracts are available through **_[Ceedling Pro][ceedling-pro]_**

[TTS-help]: https://www.throwtheswitch.org/#help-section

## Ceedling docs

* **_[Ceedling Packet][ceedling-packet]_** is Ceedling’s user manual. It also references and links to the documentation of the projects, _Unity_, _CMock_, and _CException_, that it weaves together into your test and release builds.
* **[Release Notes][release-notes]**, **[Breaking Changes][breaking-changes]**, and **[Changelog][changelog]** can be found in the **[docs/](docs/)** directory along with a variety of guides and much more.
* The **[Plugins section](https://github.com/ThrowTheSwitch/Ceedling/blob/test/ceedling_0_32_rc/docs/CeedlingPacket.md#ceedling-plugins)** within _Ceedling Packet_ lists all of Ceedling’s built-in plugins providing overviews and links to their documentation.

## Library and courses

[ThrowTheSwitch.org][TTS]:

* Provides a small but useful **[library of resources and guides][library]** on testing and using the Ceedling suite of tools.
* Discusses your **[options for running a test suite][running-options]**, particularly in the context of embedded systems.
* Links to paid courses, **_[Dr. Surly’s School for Mad Scientists][courses]_**, that provide in-depth training on creating C unit tests and using Unity, CMock, and Ceedling to do so.

## Online tutorial

Matt Chernosky’s **[detailed tutorial][tutorial]** demonstrates using Ceedling to build a C project with test suite. As the tutorial is a number of years old, the content is a bit out of date. That said, it provides an excellent overview of a real project. Matt is the author of [FFF] and the [FFF plugin][FFF-plugin] for Ceedling.

[ceedling-packet]: docs/CeedlingPacket.md
[release-notes]: docs/ReleaseNotes.md
[breaking-changes]: docs/BreakingChanges.md
[changelog]: docs/Changelog.md
[TTS]: https://throwtheswitch.org
[library]: http://www.throwtheswitch.org/library
[running-options]: http://www.throwtheswitch.org/build/which
[courses]: http://www.throwtheswitch.org/dr-surlys-school
[tutorial]: http://www.electronvector.com/blog/add-unit-tests-to-your-current-project-with-ceedling

<br/>

# 🚀 Getting Started

👀 See the **_[Quick Start](docs/CeedlingPacket.md#quick-start)_** section in Ceedling’s user manual, _Ceedling Packet_.

## The basics

### Local installation

1. Install [Ruby]. (Only Ruby 3+ supported.)
1. Install Ceedling. All supporting frameworks are included.
   ```shell
   > gem install ceedling
   ```
1. Begin crafting your project:
   1. Create an empty Ceedling project.
      ```shell
      > ceedling new <name> [<destination path>]
      ```
   1. Or, add a Ceedling project file to the root of an existing code project.
1. Run tasks like so:
   ```shell
   > ceedling test:all release
   ```

[Ruby]: https://www.ruby-lang.org/

### MadScienceLab Docker Images

As an alternative to local installation, fully packaged Docker images containing Ruby, Ceedling, the GCC toolchain, and more are also available. [Docker][docker-overview] is a virtualization technology that provides self-contained containers that are a portable, well-managed alternative to local installation of tools like Ceedling.

Two Docker image variants containing Ceedling and supporting tools exist:

1. **_[MadScienceLab][docker-image-base]_**. This image contains Ruby, Ceedling, CMock, Unity, CException, the GNU Compiler Collection (gcc), and a handful of essential C libraries and command line utilities.
1. **_[MadScienceLab Plugins][docker-image-plugins]_**. This image contains all of the above plus the command line tools that Ceedling’s built-in plugins rely on. Naturally, it is “heavier” than option (1).

See the Docker Hub pages linked above for more documentation on these images and details on the platforms on which you can run these images.

To run a _MadScienceLab_ container from your local terminal:

1. [Install Docker][docker-install]
1. Determine:
   1. The local path of your Ceedling project
   1. The variant and revision of the Docker image you’ll be using
1. Run the container with:
   1. The Docker `run` command and `-it --rm` command line options
   1. A Docker volume mapping from the root of your project to the default project path inside the container (_/home/dev/path_)

Example:

```shell
 > docker run -it --rm -v /my/local/project/path:/home/dev/project throwtheswitch/madsciencelab-plugins:1.0.0
```

When the container launches it will drop you into a Z-shell command line that has access to all the tools and utilities available within the container.

To run Ceedling from within the _MadScienceLab_ container’s shell and project working directory, just execute it as you would after installing it locally:

```shell
 dev | ~/project > ceedling help
```

```shell
 dev | ~/project > ceedling new ...
```

```shell
 dev | ~/project > ceedling test:all
```

[docker-overview]: https://www.ibm.com/topics/docker
[docker-install]: https://www.docker.com/products/docker-desktop/

[docker-image-base]: https://hub.docker.com/r/throwtheswitch/madsciencelab
[docker-image-plugins]: https://hub.docker.com/r/throwtheswitch/madsciencelab-plugins

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

See this [commented project configuration file][example-config-file] for a much more complete and sophisticated example of a project configuration.

Or, use Ceedling’s built-in `examples` & `example` commands to extract a sample project and reference its project file.

See the [configuration section][ceedling-packet-config] in _Ceedling Packet_ for way more details on your project configuration options than we can provide here.

[example-config-file]: assets/project_as_gem.yml
[ceedling-packet-config]: docs/CeedlingPacket.md#the-almighty-ceedling-project-configuration-file-in-glorious-yaml

## Using Ceedling’s command line (and related)

### Command line help

For an overview of all commands, it’s as easy as…

```sh
 > ceedling help
```

For a detailed explanation of a single command…

```sh
 > ceedling help <command>
```

### Creating a project

Creating a project with Ceedling is easy. Simply tell Ceedling the name of the
project, and it will create a directory with that name and fill it with a
default subdirectory structure and configuration file. An optional destination
path is also possible.

```shell
 > ceedling new YourNewProjectName
```

You can add files to your `src/` and `test/` directories, and they will
instantly become part of your test and/or release build. Need a different 
structure? You can modify the `project.yml` file with your new path or 
tooling setup.

#### Installing local documentation

Are you just getting started with Ceedling? Maybe you’d like your
project to be installed with some of its handy [documentation](docs/)? 
No problem! You can do this when you create a new project…

```shell
 > ceedling new --docs MyAwesomeProject
```

#### Attaching a Ceedling version to your project

Ceedling can be installed as a globally available Ruby gem. Ceedling can 
also deploy all its guts into your project instead. This allows it to 
be used without worrying about external dependencies. More importantly, 
you don’t have to worry about Ceedling changing outside of your project 
just because you updated your gems. No need to worry about changes in 
Unity or CMock breaking your build in the future.

To use Ceedling this way, tell it you want a local copy when you create
your project:

```shell
 > ceedling new --local YourNewProjectName
```

This will install all of Unity, CMock, CException, and Ceedling itself 
into a new folder `vendor/` inside your project `YourNewProjectName/`.
It will create the same simple empty directory structure for you with
`src/` and `test/` folders as the standard `new` command.

### Running build & plugin tasks

You can view all the build and plugin tasks available to you thanks to your
Ceedling project file with `ceedling help`. Ceedling’s command line help
provides a summary list from your project configuration if Ceedling is
able to find your project file (`ceedling help help` for more on this).

Running Ceedling build tasks tends to look like this…

```shell
 > ceedling test:all release
```

```shell
 > ceedling gcov:all --verbosity=obnoxious --test-case=boot --mixin=code_cruncher_toolchain
```

### Upgrading / updating Ceedling

You can upgrade to the latest version of Ceedling at any time, automatically
gaining access to any accompanying updates to Unity, CMock, and CException.

To update a locally installed gem…

```shell
 > gem update ceedling
```

Otherwise, if you are using the Docker image, you may upgrade by pulling
a newer version of the image…

```shell
 > docker pull throwtheswitch/madsciencelab:<tag>
```

If you want to force a vendored version of Ceedling inside your project to 
upgrade to match your latest gem, no problem. Just do the following…

```shell
 > ceedling upgrade --local YourNewProjectName
```

Just like with the `new` command, an `upgrade` should be executed from 
within the root directory of your project.

### Git integration

Are you using Git? You might want Ceedling to create a `.gitignore` 
that ignores the build folder while retaining control of the artifacts
folder. This will also add a `.gitkeep` file to your `test/support` folder.
You can enable this by adding `--gitsupport` to your `new` call.

```shell
 > ceedling new --gitsupport YourNewProjectName
```
<br/>

# 💻 Contributing to Ceedling Development

## Alternate installation options for Ceedling development

### Alternate local installation for development

After installing Ruby…

```shell
 > git clone --recursive https://github.com/throwtheswitch/ceedling.git
 > cd ceedling
 > git submodule update --init --recursive
 > bundle install
```

The Ceedling repository incorporates its supporting frameworks and some
plugins via Git submodules. A simple clone may not pull in the latest
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

### Alternate Docker image usage for development

As an alternative to local installation of Ceedling, nearly all development 
tasks can be accomplished with the _MadScienceLab_ Docker images.

When running an existing image as a development container, one merely needs 
to map a volume from your local Ceedling code repository to Ceedling’s 
installation location within the container. With that accomplished, 
experimenting with project builds and running self-tests is simple.

1. Start your target Docker container

   ```shell
   docker run -it --rm throwtheswitch/<image>:<tag>
   ```
1. Look up the Ceedling gem’s installation path from within the container

   ```shell
   dev | ~/project > gem info ceedling
   ```
1. Exit the container
1. Restart the container with the gem installation volume mapping and
   any other command line options you need

   ```shell
   docker run -it --rm -v /my/local/ceedling/repo:<container gem path> -v /my/local/experiment/path:/home/dev/project throwtheswitch/<image>:<tag>
   ```

For development tasks, from the container shell you can:

1. Run experiment projects you map into the container (e.g. at _/home/dev/project_).
1. Run the self-test suite. Navigate to the gem installation path discovered in (2) above. From this location, follow the instructions in the section that immediately follows.

## Running Ceedling’s self-tests

Ceedling uses [RSpec] for its tests.

To execute tests you may run the following from the root of your local 
Ceedling repository. This test suite build option balances test coverage
with suite execution time.

```shell
 > rake spec
```

To run individual test files (Ceedling’s Ruby-based tests, that is) and 
perform other tasks, use the available Rake tasks. From the root of your 
local Ceedling repo, list those task like this:

```shell
 > rake -T
```

[RSpec]: https://rspec.info

## Working in `bin/` vs. `lib/`

Most of Ceedling’s functionality is contained in the application code residing 
in `lib/`. Ceedling’s command line handling, startup configuration, project
file loading, and mixin handling are contained in a “bootloader” in `bin/`.
The code in `bin/` is the source of the `ceedling` command line tool and 
launches the application from `lib/`.

Depending on what you’re working on you may need to run Ceedling using
a specialized approach.

If you are only working in `lib/`, you can:

1. Run Ceedling using the `ceedling` command line utility you already have 
   installed. The code in `bin/` will run from your locally installed gem or 
   from within your Docker container and launch the Ceedling application for 
   you.
1. Modify a project file by setting a path value for `:project` ↳ `:which_ceedling` 
   that points to the local copy of Ceedling you cloned from the Git repository.
   See _CeedlingPacket_ for details.

If you are working in `bin/`, running `ceedling` at the command line will not
call your modified code. Instead, you must execute the path to the executable
`ceedling` in the `bin/` folder of the local Ceedling repository you are 
working on.



