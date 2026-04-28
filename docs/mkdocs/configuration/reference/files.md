# `:files` Modify file collections

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
applies to `:files` path entries — albeit with regard to filepaths and not
directory paths. The `:files` grammar and YAML examples are documented below.

## `:files` ↳ `:test`

Modify the collection of unit test C files.

**Default**: `[]` (empty)

## `:files` ↳ `:source`

Modify the collection of all source files used in unit test builds and release
builds.

**Default**: `[]` (empty)

## `:files` ↳ `:assembly`

Modify the (optional) collection of assembly files used in release builds.

**Default**: `[]` (empty)

## `:files` ↳ `:include`

Modify the collection of all source header files used in unit test builds
(e.g. for mocking) and release builds.

**Default**: `[]` (empty)

## `:files` ↳ `:support`

Modify the collection of supporting C files available to unit tests builds.

**Default**: `[]` (empty)

## `:files` ↳ `:libraries`

Add a collection of library paths to be included when linking.

**Default**: `[]` (empty)

## `:files` configuration options & notes

1. A path can be absolute (fully qualified) or relative.
1. A path can include a glob matcher (more on this below).
1. A path can use [inline Ruby string expansion][inline-ruby-string-expansion].
1. Subtractive paths prepended with a `-:` decorator are possible and useful.
   See the documentation below.

## `:files` Globs

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

## Subtractive `:files` entries

Tailoring a file collection includes adding to it but also subtracting from it.

Put simply, with an optional preceding decorator `-:`, you can instruct Ceedling
to remove certain file paths from a collection after it builds that collection.

By default, paths are additive. For pretty alignment in your YAML, you may also
use `+:`, but strictly speaking, it's not necessary.

Subtractive paths may be simple paths or globs just like any other path entry.

See examples below.

## Example `:files` YAML blurbs

### Simple `:files` tailoring

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

### Advanced `:files` tailoring

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

    # Remove test files at depth 1 beneath test/ that are of an "F series"
    # test collection FAxxxx, FBxxxx, and FCxxxx where 'x' is any character.
    - -:test/F[A-C]????
```

[globs-tutorial]: http://ruby.about.com/od/beginningruby/a/dir2.htm
[ruby-globs]: https://ruby-doc.org/core-3.0.0/Dir.html#method-c-glob
[inline-ruby-string-expansion]: ../project-file.md#inline-ruby-string-expansion
