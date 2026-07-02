# `:project`: Global project settings

!!! warning "`:project` settings will be reorganized"
    In future versions of Ceedling, test-specific and release-specific build
    settings presently organized beneath `:project` will likely be renamed and
    migrated to the `:test_build` and `:release_build` sections.

## Example `:project` YAML

```yaml
:project:
  :nane: "Acme Smartomatic"
  :build_root: project_awesome/build
  :use_exceptions: FALSE
  :use_test_preprocessor: :all
  :release_build: TRUE
  :compile_threads: :auto
```

## `:name`

Optional project name that, if present, adds a new first line to build logging 
output with the project name.

Example YAML:
```yaml
:project:
  :name: "Q-36 Space Modulator"
```

Example first logging line:
```
🌱 Q-36 SPACE MODULATOR
```

## `:build_root`

Top level directory into which generated path structure and files are placed.

!!! note "Build configuration requirement"
    This is one of the handful of configuration values that must be set for 
    any project. `:project` ↳ `:build_root` must be set for any build — release 
    build or test suite — to run.

**Default**: (none)

## `:default_tasks`

A list of default build / plugin tasks Ceedling should execute if none are
provided at the command line.

!!! note "Build & plugin tasks only"
    Build & plugin tasks include tasks such as `test:all` and `clobber`. 
    `:default_tasks` does not support application commands (e.g. `dumpconfig`) 
    or command line flags (e.g. `--verbosity`).
    
    See the documentation [on using the command line][command-line]
    to understand the distinction between application commands and build & 
    plugin tasks.

[command-line]: ../../getting-started/command-line.md

Example YAML:
```yaml
:project:
  :default_tasks:
    - clobber
    - test:all
    - release
```
**Default**: `['test:all']`

## `:use_mocks`

Configures the build environment to make use of CMock. Note that if you do not
use mocks, there's no harm in leaving this setting as its default value.

**Default**: TRUE

## `:use_partials`

Enables Ceedling Partials. [Partials][partials] allow you to test and mock
inaccessible functions and variables in the C code under test without rewriting
your source code.

[partials]: ../../testing-guide/partials/index.md

**Default**: FALSE

## `:use_test_preprocessor`

This option allows Ceedling to work with test files that contain tricky
conditional compilation statements (e.g. `#ifdef`) as well as mockable header
files containing conditional preprocessor directives and/or macros.

See the [documentation on test preprocessing][test-preprocessing] for more.

!!! note
    With any preprocessing enabled, the `gcc` & `cpp` tools must exist in an
    accessible system search path.

[test-preprocessing]: ../../testing-guide/conventions.md#ceedling-preprocessing-behavior-for-your-tests

* `:none` disables preprocessing.
* `:all` enables preprocessing for all mockable header files and test C files.
* `:mocks` enables only preprocessing of header files that are to be mocked.
* `:tests` enables only preprocessing of your test files.

**Default**: `:none`

## `:test_file_prefix`

Ceedling collects test files by convention from within the test file search
paths. The convention includes a unique name prefix and a file extension
matching that of source files.

Why not simply recognize all files in test directories as test files? By using
the given convention, we have greater flexibility in what we do with C files in
the test directories.

**Default**: "test_"

## `:release_build`

When enabled, a release Rake task is exposed. This configuration option requires
a corresponding release compiler and linker to be defined (`gcc` is used as the
default).

Ceedling is primarily concerned with facilitating the complicated mechanics of
automating unit tests. The same mechanisms are easily capable of building a
final release binary artifact (i.e. non test code — the thing that is your
final working software that you execute on target hardware). That said, if you
have complicated release builds, you should consider a traditional build tool
for these. Ceedling shines at executing test suites.

More release configuration options are available in the `:release_build` section.

**Default**: FALSE

## `:compile_threads`

A value greater than one enables parallelized build steps. Ceedling creates a
number of threads up to `:compile_threads` for build steps. These build steps
execute batched operations including but not limited to mock generation, code
compilation, and running test executables.

Particularly if your build system includes multiple cores, overall build time
will drop considerably as compared to running a build with a single thread.

Tuning the number of threads for peak performance is an art more than a
science. A special value of `:auto` instructs Ceedling to query the host
system's number of virtual cores. To this value it adds a constant of 4. This
is often a good value sufficient to "max out" available resources without
overloading available resources.

`:compile_threads` is used for all release build steps and all test suite build
steps except for running the test executables that make up a test suite. See
next section for more.

**Default**: 1

## `:test_threads`

The behavior of and values for `:test_threads` are identical to
`:compile_threads` with one exception.

`test_threads:` specifically controls the number of threads used to run the
test executables comprising a test suite.

Why the distinction from `:compile_threads`? Some test suite builds rely not on
native executables but simulators running cross-compiled code. Some simulators
are limited to running only a single instance at a time. Thus, with this and
the previous setting, it becomes possible to parallelize nearly all of a test
suite build while still respecting the limits of certain simulators depended
upon by test executables.

**Default**: 1

## `:which_ceedling`

This is an advanced project option primarily meant for development work on
Ceedling itself. This setting tells the code that launches the Ceedling
application where to find the code to launch.

This entry can be either a directory path or `gem`.

See the section [Which Ceedling](../which-ceedling.md) for full details.

**Default**: `gem`

## `:use_backtrace`

When a test executable encounters a ☠️ **Segmentation Fault** or other crash
condition, the executable immediately terminates and no further details for test
suite reporting are collected.

But, fear not. You can bring your dead unit tests back to life.

By default, in the case of a crash, Ceedling reruns the test executable for
each test case using a special mode to isolate that test case. In this way
Ceedling can iteratively identify which test cases are causing the crash or
exercising release code that is causing the crash. Ceedling then assembles the
final test reporting results from these individual test case runs.

You have three options for this setting, `:none`, `:simple`, or `:gdb`.

### `:none`
`:none` will simply cause a test report to list each test case as failed
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

### `:simple`
`:simple` causes Ceedling to re-run each test case in the test executable
individually to identify and report the problematic test case(s). This is
the default option and is described above.

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
  At line (37): "Test case crashed >> Segmentation fault (core dumped)"

-----------------------
❌ OVERALL TEST SUMMARY
-----------------------
TESTED:  5
PASSED:  4
FAILED:  1
IGNORED: 0
```

### `:gdb`
`:gdb` uses the [`gdb`][gdb] debugger to identify and report the troublesome
line of code triggering the crash. If this option is enabled, but `gdb` is
not available to Ceedling, project configuration validation will terminate
with an error at startup.

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
  At line (40): "Test case crashed >> [SIGSEGV] Segmentation fault
                `uint32_t i = *null_ptr;`
                (build/logs/test/TestUsartModel/testCrash.gdb.log)"

-----------------------
❌ OVERALL TEST SUMMARY
-----------------------
TESTED:  5
PASSED:  4
FAILED:  1
IGNORED: 0
```

**_Notes:_**

1. The default of `:simple` only works in an environment capable of using
   command line arguments (passed to the test executable). If you are targeting
   a simulator with your test executable binaries, `:simple` is unlikely to
   work for you. In the simplest case, you may simply fall back to `:none`.
   With some work and using Ceedling's various features, much more sophisticated
   options are possible.
1. The `:gdb` option currently only supports the native build platform. That is,
   the `:gdb` backtrace option cannot handle backtrace for cross-compiled code
   or any sort of simulator-based test fixture.

[gdb]: https://www.sourceware.org/gdb/

**Default**: `:simple`

<br/><br/>
