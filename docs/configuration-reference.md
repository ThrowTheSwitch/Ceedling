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
  Ceedling’s abilities. See the Ceedling plugin [subprojects](plugins/subprojects.md) for
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

  [command-line]: command-line.md

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

  [test-preprocessing]: conventions.md#ceedling-preprocessing-behavior-for-your-tests

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

  See the section [Which Ceedling](which-ceedling.md) for full details.

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
  (See more about the [Ceedling preprocessing](conventions.md#ceedling-preprocessing-behavior-for-your-tests) 
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
  (See more about the [Ceedling preprocessing](conventions.md#ceedling-preprocessing-behavior-for-your-tests) 
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
  
  See [Using Unity, CMock & CException](frameworks.md) for much more on
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
  
  See [Using Unity, CMock & CException](frameworks.md) for much more on
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
  
  See [Using Unity, CMock & CException](frameworks.md) for much more on
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
  features enabled for test files. See more in [Ceedling’s preprocessing documentation](conventions.md#preprocessing-gotchas) .
  
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

[ceedling-conventions]: conventions.md
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

[sweet-suite]: overview.md#all-your-sweet-sweet-test-suite-options

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

[custom-plugins]: development/plugin-development-guide.md
[ceedling-plugins]: plugins/index.md
[command-hooks]: plugins/command-hooks.md

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

