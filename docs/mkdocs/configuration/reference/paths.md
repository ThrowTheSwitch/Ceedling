# Project `:paths` configuration

**Paths for build tools and building file collections**

Ceedling relies on various path and file collections to do its work. File
collections are automagically assembled from paths, matching globs / wildcards,
and file extensions (see project configuration `:extension`).

Entries in `:paths` help create directory-based bulk file collections. The
`:files` configuration section is available for filepath-oriented tailoring of
these bulk file collections.

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

Examples that illustrate the many `:paths` entry features follow all the
various path-related documentation sections.

_**Note:**_ If you use Mixins to build up path lists in your project
configuration, the merge order of those Mixins will dictate the ordering of
your path lists. Particularly given that the search path list built with
`:paths` ↳ `:include` you will want to pay attention to ordering issues
involved in specifying path lists in Mixins.

## `:paths` ↳ `:test`

All C files containing unit test code. NOTE: this is one of the handful of
configuration values that must be set for a test suite.

**Default**: `[]` (empty)

## `:paths` ↳ `:source`

All C files containing release code (code to be tested).

NOTE: this is one of the handful of configuration values that must be set for
either a release build or test suite.

**Default**: `[]` (empty)

## `:paths` ↳ `:support`

Any C files you might need to aid your unit testing. For example, on occasion,
you may need to create a header file containing a subset of function signatures
matching those elsewhere in your code (e.g. a subset of your OS functions, a
portion of a library API, etc.). Why? To provide finer grained control over
mock function substitution or limiting the size of the generated mocks.

**Default**: `[]` (empty)

## `:paths` ↳ `:include`

See these two important discussions to fully understand your options for header
file search paths:

 * [Configuring Your Header File Search Paths][header-file-search-paths]
 * [`TEST_INCLUDE_PATH(...)` build directive macro][test-include-path-macro]

[header-file-search-paths]: ../../testing-guide/conventions.md#search-paths-for-test-builds
[test-include-path-macro]: ../../testing-guide/build-directives.md#test_include_path

This set of paths specifies the locations of your header files. If your header
files are intermixed with source files, you must duplicate some or all of your
`:paths` ↳ `:source` entries here.

In its simplest use, your include paths list can be exhaustive. That is, you
list all path locations where your project's header files reside in this
configuration list.

However, if you have a complex project or many, many include paths that create
problematically long search paths at the compilation command line, you may treat
your `:paths` ↳ `:include` list as a base, common list. Having established that
base list, you can then extend it on a test-by-test basis with use of the
`TEST_INCLUDE_PATH(...)` build directive macro in your test files.

**Default**: `[]` (empty)

## `:paths` ↳ `:test_toolchain_include`

System header files needed by the test toolchain — should your compiler be
unable to find them, finds the wrong system include search path, or you need a
creative solution to a tricky technical problem.

Note that if you configure your own toolchain in the `:tools` section, this
search path is largely meaningless to you. However, this is a convenient way
to control the system include path should you rely on the default [GCC][GCC]
tools.

**Default**: `[]` (empty)

## `:paths` ↳ `:release_toolchain_include`

Same as preceding albeit related to the release toolchain.

**Default**: `[]` (empty)

## `:paths` ↳ `:libraries`

Library search paths. [See `:libraries` section][libraries].

[libraries]: libraries.md

**Default**: `[]` (empty)

## `:paths` ↳ `:<custom>`

Any paths you specify for custom list. List is available to tool configurations
and/or plugins. Note a distinction — the preceding names are recognized
internally to Ceedling and the path lists are used to build collections of
files contained in those paths. A custom list is just that — a custom list of
paths.

## `:paths` configuration options & notes

1. A path can be absolute (fully qualified) or relative.
1. A path can include a glob matcher (more on this below).
1. A path can use [inline Ruby string expansion][inline-ruby-string-expansion].
1. Subtractive paths are possible and useful. See the documentation below.
1. Path order beneath a subsection (e.g. `:paths` ↳ `:include`) is preserved
   when the list is iterated internally or passed to a tool.

## `:paths` Globs

Globs are effectively fancy wildcards. They are not as capable as full regular
expressions but are easier to use. Various OSs and programming languages
implement them differently.

For a quick overview, see this [tutorial][globs-tutotrial].

Ceedling supports globs so you can specify patterns of directories without the
need to list each and every required path.

Ceedling `:paths` globs operate similarly to [Ruby globs][ruby-globs] except
that they are limited to matching directories within `:paths` entries and not
also files. In addition, Ceedling adds a useful convention with certain uses of
the `*` and `**` operators.

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

Special conventions:

* If a globified path ends with `/*` or `/**`, the resulting list of
  directories also includes the parent directory.

See the example `:paths` YAML blurb section.

[globs-tutotrial]: http://ruby.about.com/od/beginningruby/a/dir2.htm
[ruby-globs]: https://ruby-doc.org/core-3.0.0/Dir.html#method-c-glob

## Subtractive `:paths` entries

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
Mixins to your heart's content. The subtractive paths are not removed until all
Mixins have been merged.

## Example `:paths` YAML blurbs

_NOTE:_ Ceedling standardizes paths for you. Internally, all paths use forward
slash `/` path separators (including on Windows), and Ceedling cleans up
trailing path separators to be consistent internally.

### Simple `:paths` entries

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

### Common `:paths` globs with subtractive path entries

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

### Advanced `:paths` entries with globs and string expansion

```yaml
:paths:
  :test:                             
    - test/**/f???             # Every 4 character "f-series" subdirectory beneath test/

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

[GCC]: https://gcc.gnu.org
[inline-ruby-string-expansion]: ../project-file.md#inline-ruby-string-expansion
