# Dependencies

This plugin fetches, builds, and links the libraries and modules your project depends
on. It’s rare for an embedded project to be built completely free of other code. Some of
it may be standard internal libraries, and some may be third-party libraries. Either way,
it becomes part of the project’s ecosystem.

For each dependency, you tell this plugin where to fetch it from, how to build it, and what
it produces. Ceedling fetches and builds it whenever those outputs are missing, then adds
its headers, sources, and libraries to your test and release builds.

Most third-party libraries already have a build process of their own. Make? CMake? A
custom series of scripts that only a mad scientist could possibly understand? No matter.
You list the commands, and Ceedling runs them.

See the [_Cookbook_ section](#cookbook) for real-world scenarios along with the example 
`:dependencies` configurations and `ceedling dependencies:...` command lines to make
use of this plugin.

## So how does all this magic work?

Enable the plugin in your project configuration, then list your dependencies under
`:dependencies` ↳ `:deps`. Each dependency has a series of fields, most of them optional.
If you don’t need a feature, leave its field out. In the end, it looks something like
this:

```yaml
:plugins:
  :enabled:
    - dependencies

:dependencies:
  :deps:
    - :name: WolfSSL
      :paths:
        :fetch:    third_party/wolfssl/source
        :source:   third_party/wolfssl/source
        :build:    third_party/wolfssl/build
        :artifact: third_party/wolfssl/install
      :fetch:
        :method: :zip
        :source: \\shared_drive\third_party_libs\wolfssl\wolfssl-4.2.0.zip
      :environment:
        - CFLAGS+=-DWOLFSSL_DTLS_ALLOW_FUTURE
      :build:
        - autoreconf -i
        - ./configure --enable-tls13 --enable-singlethreaded
        - make
        - make install
      :artifacts:
        :static_libraries:
          - lib/wolfssl.a
        :dynamic_libraries:
          - lib/wolfssl.so
        :includes:
          - include/**
```

## Name

As a YAML array of objects, each dependency begins with a dash, followed by its fields.
By convention, `:name` comes first, which makes each dependency easy to spot.

The name appears in Ceedling’s progress messages. Its letters, digits, and underscores
also name the dependency’s own tasks, so `Worker Bees` gets `dependencies:make:WorkerBees`.
A name therefore needs at least one letter or digit. Two dependencies whose names reduce
to the same task name stop the build with an error.

## Working paths

A dependency’s paths are collected under its `:paths`. Each path you leave out falls back
to another, and with none configured every path is `dependencies/<task name>`.

| Path | Purpose | When left out |
|---|---|---|
| `:fetch` | Where the dependency is fetched to | `:source` |
| `:source` | Where build commands run from | `:fetch` |
| `:build` | Where the build places its files | `:source`, then `:fetch` |
| `:artifact` | Where the outputs listed under `:artifacts` are found | `:build` |
| `:deploy` | Where `dependencies:deploy` copies dynamic libraries and executables | Your release executable’s folder |

Cleaning a dependency never removes its `:deploy` path, which holds copies alongside your
project’s own files.

If the dependency is part of your repository (its fetch `:method` is `:none`), `:source`
is where its code already lives. Paths may lie outside your project, such as
`../shared/lib`, and headers found there work in test and release builds alike.

Every artifact is relative to the `:artifact` path. With several include directories,
choose the highest level and list the rest relative to it.

## Fetching dependencies

The plugin fetches a dependency with one of several common methods, configured under its
`:fetch`:

- `:method`, the way this dependency is fetched:
    - `:none`: the code is already part of the project, so nothing is fetched.
    - `:zip`: unpack a zip archive into the fetch path.
    - `:tar_gzip`: unpack a gzipped tar archive into the fetch path.
    - `:git`: clone a git repository into the fetch path.
    - `:svn`: check out a Subversion repository into the fetch path.
    - `:custom`: run commands of your own in the fetch path.
- `:source`: the archive or repository to fetch from (`:zip`, `:tar_gzip`, `:git`, and
  `:svn`, all of which require it).
- `:tag` or `:branch`: the tag or branch to clone (`:git` only, optional). A tag wins
  when both are given.
- `:hash`: the commit to check out (`:git` only, optional). It makes a full clone rather
  than a shallow one, so the commit is available.
- `:revision`: the revision to check out (`:svn` only, optional).
- `:executable`: the list of commands to run (`:custom` only, required).

Fetching runs from inside the fetch path, so an archive `:source` given as a relative
path is relative to the fetch path.

A dependency is fetched once. Once its fetch path holds files, fetching it again, or
building it after a fetch, leaves those files alone. To fetch a fresh copy, clean the
dependency first with `dependencies:clean`.

The `:zip`, `:tar_gzip`, `:git`, and `:svn` methods use the plugin’s
[tools](#custom-tools) (`unzip`, `tar`, `git`, and `svn`). Each is checked just before a
dependency fetches with it, so a missing tool stops only that fetch, and a machine that
never fetches, such as a CI agent working from fetched dependencies, needs none of them.

## Environment variables

Many build systems take settings from environment variables. A dependency’s
`:environment` sets variables while that dependency’s fetch and build commands run, then
restores them, so they never reach another dependency or Ceedling itself.

Ceedling’s project configuration also has a top-level `:environment` section, which
applies to all of Ceedling. The two sections differ in format and abilities.

Each entry sets a variable, adds to it, or removes from it:

```yaml
:dependencies:
  :deps:
    - :name: Engine
      :environment:
        - ARCHITECTURE=ARM9
        - CFLAGS+= -DADD_AWESOMENESS
        - CFLAGS-= -DWASTE
```

`ARCHITECTURE=ARM9` sets `ARCHITECTURE` to `ARM9`. `+=` appends to a variable, here
adding ` -DADD_AWESOMENESS` to `CFLAGS`, and `-=` removes text from it, here removing
` -DWASTE`. An entry in any other form stops the build with an error.

When appending, Ceedling cannot know which delimiter you expect, so include it yourself:
a space for compiler flags, or `:` (`;` on Windows) for `PATH`. Text after `+=` and `-=`
is used exactly as written, leading space included, while a value after `=` loses its
leading spaces. Removing text is case
sensitive and removes only an exact match. Appending to or removing from a variable that
is not set leaves it set, empty if nothing was appended.

## Building dependencies

The heart of the plugin is the build process you specify for each dependency under
`:build`, a list of steps Ceedling runs in order. Any tools those steps use must be
installed. A failing step stops the build with its error.

Each step is a command line, which runs from the dependency’s `:source` path exactly as
written, quoting and spacing included. The source, build, and artifact paths are created
first if they do not exist. A step can instead be `:build_lib`, which builds a static
library with Ceedling’s own compiler and archiver (see [Custom tools](#custom-tools)).

## Artifacts

Artifacts are the outputs of the build process, listed under `:artifacts`. A dependency
may have any of them or none. Your dependency’s build process may produce many other
files, but these are the ones Ceedling acts on.

### `static_libraries`

Static libraries Ceedling links into your test and release builds. If one does not
exist, Ceedling fetches and builds the dependency to produce it.

### `dynamic_libraries`

Dynamic libraries Ceedling links into your test and release builds. If one does not
exist, Ceedling fetches and builds the dependency to produce it. `dependencies:deploy`
copies them to the [`:deploy` path](#working-paths), by default beside your release
executable, where it loads them at run time.

### `executables`

Programs a dependency builds, such as a code generator, a flashing utility, or a tool
your release ships alongside it. Ceedling never links them. A release build, or
`dependencies:make`, fetches and builds the dependency when one does not exist, while
test builds do not wait on them. `dependencies:deploy` copies them, with any dynamic
libraries, to the [`:deploy` path](#working-paths).

On Windows, list each executable with its `.exe` extension.

### `includes`

The public headers a dependency provides. Ceedling adds their directories to its search
paths, so your code can include them and your tests can mock them. An entry may be:

- a header file, such as `include/wolfssl.h`, which adds that file’s directory;
- a directory, such as `include`;
- a glob, such as `include/**`, which adds every directory it finds.

### `source`

Directories of C files a dependency produces, such as generated code. Ceedling adds the
directories to its search paths and their C files to your release build.

## Tasks

Once configured, the plugin works on its own: a release or test build fetches and builds
any dependency whose outputs are missing. These tasks let you act on dependencies
directly. Each also works on a single dependency by its task name, such as
`dependencies:make:WorkerBees`.

### `ceedling dependencies:fetch`

Fetches each dependency that is not fetched yet. Dependencies without fetch settings, or
fetched by `:none`, are left alone.

### `ceedling dependencies:make`

Fetches each dependency if needed, then builds any whose outputs are missing. This
happens automatically in a release build, but is handy while you are configuring a
dependency.

### `ceedling dependencies:clean`

Removes a fetched dependency entirely, every one of its working paths, so the next build
fetches and builds it from scratch. A dependency fetched by `:none` keeps its source and
loses only its artifact path. A dependency without fetch settings is left alone.

### `ceedling dependencies:deploy`

Copies every dynamic library and executable of each dependency to its
[`:deploy` path](#working-paths), by default beside your release executable. An artifact
that has not been built is built first.

### `files:dependencies`

Lists every static library, dynamic library, and executable your dependencies provide.

### `paths:include`

Lists every header search path Ceedling uses, including those from dependencies.

### `files:include`

Lists every header file Ceedling has found, including those from dependencies.

## Custom tools

The plugin’s tools are configured like any other Ceedling tool, and you can replace them
under `:tools`:

| Tool | Default | Used for |
|---|---|---|
| `:deps_compiler` | `gcc` | `:build_lib` compiling |
| `:deps_assembler` | none | `:build_lib` assembling, needed only for assembly files |
| `:deps_linker` | `ar` | `:build_lib` archiving |
| `:deps_zip` | `unzip` | `:zip` fetching |
| `:deps_targzip` | `tar` | `:tar_gzip` fetching |
| `:deps_git_clone`, `:deps_git_checkout` | `git` | `:git` fetching |
| `:deps_subversion` | `svn` | `:svn` fetching |

The compiler, assembler, and archiver are checked just before `:build_lib` uses them, so
a project without `:build_lib` needs none of them.

`:build_lib` compiles every C file anywhere under the dependency’s `:source` path, with
every directory holding a header there as a search path. It then archives the objects
into the first library under `:artifacts` ↳ `:static_libraries`, built in the `:build`
path and copied to the `:artifact` path when the two differ. A dependency’s own
`:defines` and `:flags` apply to its compilation, and `:libraries` and `:libpaths` to its
archiving.

The compiler receives its search paths as `${5}` and its defines as `${6}`, as Ceedling’s
own compilers do:

```yaml
:tools:
  :deps_compiler:
    :executable: gcc
    :arguments:
      - -g
      - -I"${5}"
      - -D${6}
      - -c "${1}"
      - -o "${2}"
  :deps_linker:
    :executable: ar
    :arguments:
      - rcs
      - ${2}
      - ${1}
```

A dependency built with `:build_lib` looks like this:

```yaml
:dependencies:
  :deps:
    - :name: CaptainCrunch
      :paths:
        :source:   ../cc/
        :build:    ../cc/build
        :artifact: ../cc/build
      :fetch:
        :method: :none
      :build:
        - :build_lib
      :artifacts:
        :static_libraries:
          - release/cc.a
        :includes:
          - ./cc.h
      :defines:
        - THESE_GET_USED_DURING_COMPILATION
```

## Cookbook

Each recipe below pairs a dependency’s configuration with the commands that work with
it. Any of them can sit alongside the others in one `:deps` list.

### A tagged release from git, built with Make

Your drone flight controller firmware uses an open-source sensor fusion library, which
blends accelerometer and gyroscope readings into an orientation. Its maintainers publish
tagged releases on GitHub and build it with a makefile.

Pin a library to a release tag so every developer and CI run builds the same code. The
clone is shallow, which keeps it quick.

```yaml
:dependencies:
  :deps:
    - :name: Sensor Fusion
      :paths:
        :fetch:    third_party/fusion
        :artifact: third_party/fusion/out
      :fetch:
        :method: :git
        :source: https://github.com/example/sensor-fusion.git
        :tag:    v2.4.1
      :build:
        - make lib OUT=out
      :artifacts:
        :static_libraries:
          - libfusion.a
        :includes:
          - ../include/**
```

```sh
ceedling dependencies:make     # Clone v2.4.1 if needed, then build libfusion.a
ceedling release               # Link it into the release build
```

To move to a new tag, change `:tag`, then fetch a fresh copy, since a fetched dependency
is not fetched again:

```sh
ceedling dependencies:clean:SensorFusion dependencies:make:SensorFusion
```

### A vendor archive with environment settings

Your chip vendor ships its real-time operating system as a zip archive, which your team
keeps on a shared file server. It builds with an autotools configure script, which must
be told to cross-compile for your ARM Cortex-M4 target.

Unpack a zip from a shared location and build it with the vendor’s own configure script,
passing settings through the environment of that build alone.

```yaml
:dependencies:
  :deps:
    - :name: VendorRTOS
      :paths:
        :fetch:    third_party/rtos/source
        :build:    third_party/rtos/source/build
        :artifact: third_party/rtos/install
      :fetch:
        :method: :zip
        :source: /mnt/vendor/rtos-5.2.zip
      :environment:
        - CC=arm-none-eabi-gcc
        - CFLAGS+= -mcpu=cortex-m4
      :build:
        - ./configure --prefix=../install
        - make install
      :artifacts:
        :static_libraries:
          - lib/librtos.a
        :includes:
          - include
```

```sh
ceedling dependencies:fetch:VendorRTOS   # Unpack the archive
ceedling dependencies:make:VendorRTOS    # Configure and build with CC and CFLAGS set
```

### A sibling Ceedling project

Your repository holds two Ceedling projects side by side: the main application and a
supervisor module that watches over it. The supervisor is developed and unit tested in
its own project, and the application links it as a library.

Build a library from another Ceedling project in the same repository, using that
project’s own release build. It is never fetched, so cleaning removes only its build
outputs.

```yaml
:dependencies:
  :deps:
    - :name: Supervisor
      :paths:
        :source:   ../supervisor
        :build:    ../supervisor/build
        :artifact: ../supervisor/build/release
      :fetch:
        :method: :none
      :build:
        - ceedling clobber release
      :artifacts:
        :static_libraries:
          - libsupervisor.a
        :includes:
          - ../../src/supervisor.h
```

```sh
ceedling dependencies:make:Supervisor    # Run the sibling project’s release build
ceedling test:all                        # Test against its library and header
ceedling dependencies:clean:Supervisor   # Remove only its release outputs
```

### A shared library deployed beside the release

Your Linux-based product decodes audio with a third-party codec, built as a shared
library the application loads when it starts. You keep the codec’s source release in the
project’s `downloads` folder.

Build a dynamic library and copy it beside the release executable, which loads it at run
time.

```yaml
:dependencies:
  :deps:
    - :name: Codec
      :paths:
        :fetch:    third_party/codec
        :artifact: third_party/codec/lib
      :fetch:
        :method: :tar_gzip
        :source: ../../downloads/codec-1.8.tar.gz
      :build:
        - make shared
      :artifacts:
        :dynamic_libraries:
          - libcodec.so
        :includes:
          - ../include
```

```sh
ceedling release dependencies:deploy   # Build, link, then copy libcodec.so beside the executable
```

The archive’s relative `:source` resolves from inside the fetch path, which is why it
climbs two folders.

### Build tools deployed to a shared folder

`packer` is an in-house utility your tools team keeps in its own git repository. It
bundles a compiled firmware image with its version metadata into a signed update file,
and its companion `packer-verify` checks such a file. Your release scripts run both from
the project’s `tools/bin` folder, so every developer and CI agent needs them built from
the same tagged version and installed there.

Build tools from source and install them where your build scripts or CI agents expect
them. Ceedling builds them for a release, never links them, and never cleans the deploy
folder.

```yaml
:dependencies:
  :deps:
    - :name: Packer
      :paths:
        :fetch:  third_party/packer
        :build:  third_party/packer/build
        :deploy: tools/bin
      :fetch:
        :method: :git
        :source: https://github.com/example/firmware-packer.git
        :tag:    v1.3.0
      :build:
        - make all BUILD=build
      :artifacts:
        :executables:
          - packer
          - packer-verify
```

```sh
ceedling dependencies:deploy:Packer   # Clone, build, then copy both tools to tools/bin
```

### A small library compiled by Ceedling

A colleague’s CRC routines live in your company’s Subversion repository: a C file and
a header, with no makefile and no library of their own. Your firmware checks its data
packets with them.

Pin a few C files from Subversion and let `:build_lib` compile and archive them, with no
build system of their own.

```yaml
:dependencies:
  :deps:
    - :name: CRC Utils
      :paths:
        :fetch: third_party/crc
        :build: third_party/crc/build
      :fetch:
        :method:   :svn
        :source:   https://svn.example.com/repos/crc/trunk
        :revision: '1287'
      :build:
        - :build_lib
      :artifacts:
        :static_libraries:
          - libcrc.a
        :includes:
          - ../crc.h
      :defines:
        - CRC_TABLE_IN_ROM
```

```sh
ceedling dependencies:make:CRCUtils   # Check out revision 1287, then compile and archive
ceedling files:dependencies           # Confirm third_party/crc/build/libcrc.a is listed
```

<br/><br/>
