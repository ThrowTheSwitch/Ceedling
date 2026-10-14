# Module Generator

This plugin adds commands to Ceedling that create a module’s source, header, and test
files from templates; remove them again; and stub a source file from its header. Files
land in your project’s [`:paths`][paths], guided by optional hints.

## Overview

Enable the plugin by adding `module_generator` to the enabled [plugins][plugins] list in
your project configuration:

```yaml
:plugins:
  :enabled:
    - module_generator
```

Then a single call creates a new module:

```sh
ceedling "module:create[MadScience]"
```

This creates `MadScience.c`, `MadScience.h`, and `test_MadScience.c`. The test file
carries your project’s [`:test_file_prefix`][test-file-prefix]. Names keep the case you type unless you
configure a [naming convention](#naming-convention).

Several modules can be named in one call, separated by commas. Leave no spaces between
the brackets or rely on surrounding quotes; your shell would otherwise split the command.

```sh
ceedling "module:create[MadScience,EvilGenius,SecretLair]"
```

The plugin’s three commands take the same arguments:

| Command | Does |
|---|---|
| `module:create[...]` | Creates each module’s files, skipping any that already exist and stopping when all of them do |
| `module:destroy[...]` | Removes each module’s files |
| `module:stub[...]` | Writes a source file of function stubs from each module’s header |
| `module:test[...]` | Writes a test file with a test for each function in each module’s header |

A name that begins with your test file prefix asks for a test file alone.
`"module:create[test_MadScience]"` creates only `test_MadScience.c`. When the prefix ends
in a letter or digit, as a prefix of `Test` does, the character after the prefix must
not be a lowercase letter or digit. An uppercase letter starts the module name, so
`TestMadScience` is a test file for `MadScience`, while `Testimony` and `Test2Widget`
are modules. A prefix ending in a separator, like the default `test_`,
needs no such check.

## Patterns

A pattern creates a set of related modules at once. Name it after the module:

```sh
ceedling "module:create[SecretLair,mch]"
```

This creates nine files: a source, header, and test file each for `SecretLair_Model`,
`SecretLair_Conductor`, and `SecretLair_Hardware`. With `:naming` set to `:bumpy`, the
same call creates `SecretLairModel`, `SecretLairConductor`, and `SecretLairHardware`.
Each generated module includes the headers its role depends on, and each test includes
the mocks of those headers.

The module generator understands the following patterns:

- `src` — a source, header, and test file (the default)
- `test` — only a test file
- `mch` — 9 files for the [model-conductor-hardware (pdf)][mch-paper] pattern ([html][mch-article])
- `mvp` — 9 files for the [model-view-presenter][mvp-wikipedia] pattern
- `dh` — 6 files for the driver-hardware pattern
- `dih` — 9 files for the driver-interrupt-hardware pattern

The `dh` and `dih` patterns are alternate namings and conceptual organizations of the
model-conductor-hardware pattern.

[mch-paper]: https://cdn.prod.website-files.com/628fcc1631ad0b25b32f223e/62e43a26764867e95fe5a138_ESC-413Paper_KarleskyWilliams.pdf
[mch-article]: https://www.methodsandtools.com/archive/archive.php?id=59
[mvp-wikipedia]: https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93presenter

A pattern applies to every module in the call, and a call takes one pattern. The first
argument is always a module name, even one spelled like a pattern.

## Paths

Without any hint, each kind of file goes to the first path listed for it under
[`:paths`][paths]. Source files go to the first `:source` path, headers to the first `:include`
path, and tests to the first `:test` path. Headers go with the source when your project
lists no include paths. To choose other default locations, configure them:

```yaml
:module_generator:
  :path_src: src/
  :path_inc: include/
  :path_tst: test/
```

### Path hints

A hint before a colon steers a module toward matching paths:

```sh
ceedling "module:create[lab:SecretLair,mch]"
```

The hint is matched separately against your source, include, and test paths, and each
kind of file goes to the path the hint matches best. A path matches best when its
trailing folders match the hint. When the hint matches nothing among one kind of path,
those files go to the first path of that kind. When it matches nothing at all, the
command stops with an error and creates nothing.

Say your project lists these paths:

```yaml
:paths:
  :source:
    - lab/src
    - lair/src
    - other/src
  :test:
    - lab/test
    - lair/test
    - other/test
```

The `lab:` hint places files here:

- source files: `lab/src` (a close match)
- include files: `lab/src` (no include paths are listed, so headers go with the source)
- test files: `lab/test` (a close match)

Instead, say your paths look like this:

```yaml
:paths:
  :source:
    - src/**   # might contain subfolders lab, lair, and other
  :include:
    - inc/**   # might contain subfolders lab, lair, other, and shared
  :test:
    - test
```

Now the `lab:` hint places files here:

- source files: `src/lab` (a close match)
- include files: `inc/lab` (a close match)
- test files: `test` (no close match, so the first test path)

A few more notes about hints:

1. Several hints narrow the match through nested folders. `lab:secret:lair` places
   `lair.c` in a folder like `my/lab/secret/`.
2. Among equally good matches, and without any hint, the order of your paths in the
   project file decides.
3. With a `**` glob under `:paths`, the parent folder comes first, then its
   subfolders alphabetically, and so on.
4. A hint may be an absolute path, including one with a Windows drive letter, as in
   `C:/project/lab:SecretLair`.

More complicated structures will sometimes place a file in the wrong folder, and you
can move it afterward. A project with a consistent structure gets good placement.

### Adding to paths

A slash in the name, rather than a colon, names a subdirectory to use as given. The
module generator creates it if it does not exist. With the second set of paths above,
this call:

```sh
ceedling "module:create[newlab/SecretLair]"
```

creates these files:

- `src/newlab/SecretLair.c`
- `inc/newlab/SecretLair.h`
- `test/newlab/test_SecretLair.c`

A hint and a slash can combine, as in `lab:newlab/SecretLair`. A hint picks among
existing paths, and the slash then adds a subdirectory below the chosen path.

The module generator does not check whether a new subdirectory is covered by your
`:paths`. You can create files before updating your project file. You might also create
a file Ceedling does not see until you add its folder to `:paths`.

### Same-named files

`module:create` warns about each existing source, header, or test file elsewhere in your
project that shares a name with a file it is about to create, then creates the module.
Ceedling distinguishes same-named files by their paths, so this is allowed. The warning
catches the case where you meant to work with the existing module instead.

## Stubbing

`module:stub` writes a source file containing a stub for each function its header
declares:

```sh
ceedling "module:stub[SecretLair]"
```

This reads `SecretLair.h` from your include path and writes `SecretLair.c` to your
source path. If `SecretLair.c` already exists, only stubs for newly declared functions
are added, and your existing code is left alone.

Hints and slashes work as they do for `module:create`. `"module:stub[lab:rev/SecretLair]"`
reads `rev/SecretLair.h` below the include path `lab:` matches and writes
`rev/SecretLair.c` below the matching source path.

Headers are parsed with your project’s [`:cmock`][cmock] settings, the same ones that generate
your mocks, so options like `:strippables` and `:treat_as` apply to stubs too.

## Testing from headers

`module:test` writes a test file containing an ignored test for each function its
module’s header declares, a starting point for testing a module that already exists:

```sh
ceedling "module:test[SecretLair]"
```

This reads `SecretLair.h` from your include path and writes `test_SecretLair.c` to your
test path, with a `test_<function>_NeedToImplement` test for each function. Each test
calls `TEST_IGNORE_MESSAGE()` until you fill it in.

Run it again after adding functions to the header, and only tests for the new functions
are added, ahead of the file’s closing `#endif`. A function already counts as tested by
any test named `test_<function>` or `test_<function>_<anything>`, so your own
descriptive test names are respected and your existing tests are left alone.

Hints and slashes work as they do for `module:create`. The test file uses your
configured [includes](#includes), [boilerplate](#boilerplates),
[test define](#test-defines), and [test guard](#test-guards). Headers are parsed with
your project’s [`:cmock`][cmock] settings, as for [stubbing](#stubbing).

## Destroying

`module:destroy` removes the files `module:create` would make for the same arguments,
pattern and hints included:

```sh
ceedling "module:destroy[lab:SecretLair,mch]"
```

A file that does not exist is reported and skipped.

## Configuration

The module generator runs as-is with its defaults. Every setting lives under
`:module_generator` in your project file:

| Setting | Purpose | Default |
|---|---|---|
| `:naming` | File [naming convention](#naming-convention) | none (names keep their case) |
| `:path_src`, `:path_inc`, `:path_tst` | [Default locations when no hint is given](#default-paths) | first path of each `:paths` list |
| `:includes` | [Headers every generated file includes](#includes) | none |
| `:boilerplates` | [Text at the top of every generated file](#boilerplates) | none |
| `:boilerplate_files` | [Files holding that text instead](#boilerplate-files) | none |
| `:test_define` | [Symbol guarding each test file](#test-defines) | `TEST` |
| `:test_guard` | [`#ifdef` or `#if` around each test file](#test-guards) | `:ifdef` |

### Naming convention

A naming convention keeps everyone’s file names consistent, whatever case a name is
typed in. Words are found at underscores, spaces, and changes of case, so
`mad_science` and `MadScience` name the same module.

```yaml
:module_generator:
  :naming: :bumpy
```

The options for `:naming`, and the source file each creates for this command:

```sh
ceedling "module:create[mad_science]"
```

| `:naming` | Style | Source file |
|---|---|---|
| `:bumpy` | BumpyFilesLookLikeSo | `MadScience.c` |
| `:camel` | camelFilesAreSimilarButStartLow | `madScience.c` |
| `:snake` | snake_case_is_all_lower_and_uses_underscores | `mad_science.c` |
| `:caps` | CAPS_FEELS_LIKE_YOU_ARE_SCREAMING | `MAD_SCIENCE.c` |

The header and test file follow the same convention, as do a pattern’s module names.
Without `:naming`, names keep the case you type.

### Default paths

`:path_src`, `:path_inc`, and `:path_tst` choose where files go when a command gives no
[hint](#path-hints). A hint still matches against your `:paths` and ignores these
settings.

```yaml
:module_generator:
  :path_src: src/
  :path_inc: include/
  :path_tst: test/
```

With these settings, this command:

```sh
ceedling "module:create[Widget]"
```

creates `src/Widget.c`, `include/Widget.h`, and `test/test_Widget.c`.

### Includes

Every generated file of a kind can include a standard list of headers. `:src` lists
those for source files, `:inc` for headers, and `:tst` for tests:

```yaml
:module_generator:
  :includes:
    :src:
      - board.h
    :inc:
      - types.h
    :tst:
      - defs.h
      - board.h
```

With these settings, this command:

```sh
ceedling "module:create[Widget]"
```

creates `Widget.c` including `board.h`, `Widget.h` including `types.h`, and
`test_Widget.c` including `defs.h` and `board.h`, each ahead of the module’s own
includes.

### Boilerplates

A boilerplate is text placed at the top of each generated file, the handy place for a
copyright notice. Each kind of file has its own. A boilerplate may contain `%1$s`, which
is replaced with the module name.

```yaml
:module_generator:
  :boilerplates:
    :src: |
      /***************************
      * %1$s
      * This file is Awesome.
      * That is All.
      ***************************/
    :inc: |
      /***************************
      * Header. Woo.             *
      ***************************/
    :tst: |
      /***************************
      * My Awesome Test For %1$s
      ***************************/
```

With these settings, this command:

```sh
ceedling "module:create[Widget]"
```

creates `Widget.c` beginning with the source boilerplate, its second line reading
`* Widget`, and `test_Widget.c` beginning with `* My Awesome Test For Widget`.

### Boilerplate files

A boilerplate can instead live in a file, which keeps long notices out of your project
file. `:boilerplate_files` names a file for any kind, and that file’s contents replace
the kind’s `:boilerplates` text. A named file that does not exist stops the command.

```yaml
:module_generator:
  :boilerplate_files:
    :src: config/boilerplate_source.txt
    :tst: config/boilerplate_test.txt
```

With these settings, this command:

```sh
ceedling "module:create[Widget]"
```

creates `Widget.c` beginning with the contents of `config/boilerplate_source.txt` and
`test_Widget.c` beginning with the contents of `config/boilerplate_test.txt`. `Widget.h`
uses the `:inc` boilerplate, if any.

### Test defines

Each generated test file is wrapped in `#ifdef TEST`. `:test_define` names a
different symbol.

```yaml
:module_generator:
  :test_define: CEEDLING_TEST
```

With this setting, this command:

```sh
ceedling "module:create[Widget]"
```

creates `test_Widget.c` wrapped in `#ifdef CEEDLING_TEST` and `#endif // CEEDLING_TEST`.

The symbol must be defined for your test builds, or every generated test compiles to
nothing. Add it under [`:defines`][defines] ↳ `:test`:

```yaml
:defines:
  :test:
    - CEEDLING_TEST
```

`module:create` and `module:test` warn about each generated test file whose build would
not define the symbol. Each file is checked as a test build would compile it, so a symbol
under a per-test matcher counts only for the test files that matcher matches.

### Test guards

Each generated test file is guarded with `#ifdef`. Some coding standards forbid `#ifdef`
in favor of `#if`, and `:test_guard` set to `:if` uses `#if` instead. The options are
`:ifdef` (the default) and `:if`.

```yaml
:defines:
  :test:
    - UNIT_TEST

:module_generator:
  :test_define: UNIT_TEST
  :test_guard: :if
```

With these settings, this command:

```sh
ceedling "module:create[Widget]"
```

creates `test_Widget.c` wrapped in `#if UNIT_TEST` and `#endif // UNIT_TEST`. With
`#if`, the symbol must be defined to a nonzero value. A bare `UNIT_TEST` under `:defines`
is defined as `1`.

[plugins]: ../configuration/reference/plugins.md
[paths]: ../configuration/reference/paths.md
[test-file-prefix]: ../configuration/reference/project.md#test_file_prefix
[cmock]: ../configuration/reference/cmock.md
[defines]: ../configuration/reference/defines.md

<br/><br/>
