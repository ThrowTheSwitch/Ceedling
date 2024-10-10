ceedling-dependencies
=====================

Plugin for supporting release dependencies. It's rare for an embedded project to
be built completely free of other libraries and modules. Some of these may be
standard internal libraries. Some of these may be 3rd party libraries. In either
case, they become part of the project's ecosystem.

This plugin is intended to make that relationship easier. It allows you to specify
a source for dependencies. If required, it will automatically grab the appropriate
version of that dependency.

Most 3rd party libraries have a method of building already in place. While we'd
love to convert the world to a place where everything downloads with a test suite
in Ceedling, that's not likely to happen anytime soon. Until then, this plugin
will allow the developer to specify what calls Ceedling should make to oversee
the build process of those third party utilities. Are they using Make? CMake? A
custom series of scripts that only a mad scientist could possibly understand? No
matter. Ceedling has you covered. Just specify what should be called, and Ceedling
will make it happen whenever it notices that the output artifacts are missing.

Output artifacts? Sure! Things like static and dynamic libraries, or folders
containing header files that might want to be included by your release project.

So how does all this magic work?

First, you need to add the Dependencies plugin to your list of enabled plugins. Then, we'll 
add a new comfiguration section called `:dependencies`. There, you can list as many 
dependencies as you desire. Each has a series of fields that help Ceedling to understand 
your needs. Many of them are optional. If you don't need that feature, just don't include 
it! In the end, it'll look something like this:

```yaml
:plugins:
  :enabled:
    - dependencies

:dependencies:
  :deps:
    - :name: WolfSSL
      :paths:
        :fetch:        third_party/wolfssl/source
        :source:       third_party/wolfssl/source
        :build:        third_party/wolfssl/build
        :artifact_lib: third_party/wolfssl/install
        :artifact_inc: third_party/wolfssl/install
      :fetch:
        :method: :zip
        :source: \\shared_drive\third_party_libs\wolfssl\wolfssl-4.2.0.zip
      :environment:
        - CFLAGS+=-DWOLFSSL_DTLS_ALLOW_FUTURE
      :build:
        - "autoreconf -i"
        - "./configure --enable-tls13 --enable-singlethreaded"
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

Let's take a deeper look at each of these features.

The Starting Dash & Name
------------------------

Yes, that opening dash tells the dependencies plugin that the rest of these fields
belong to our first dependency. If we had a second dependency, we'd have another
dash, lined up with the first, and followed by all the fields indented again.

By convention, we use the `:name` field as the first field for each tool. Ceedling
honestly doesn't care which order the fields are given... but as humans, it makes
it easier for us to see the name of each dependency with starting dash.

The name field is only used to print progress while we're running Ceedling. You may
call the name of the field whatever you wish.

Working Paths
-------------

All paths are collected under `:dependencies` ↳ `:paths`. The `:source` field allows us 
to specify where the source code for each of our dependencies is stored. By default, it's
the same as the `:fetch` path, which is where source will be fetched TO when fetching the 
dependency from elsewhere. All commands to build this dependency will be executed from
the `:source` location. Temporary data will be placed in the `:build` location. Unless you're
using one of Ceedling's built-in builders, you'll need to learn where the tool you're using to
build places it's built artifacts , and list that here. Finally, the output
artifacts will be referenced to this location. You override this by specifying a `:artifact`
path. In summary:

 - `:paths`
   - `:fetch` -- where things are fetched to (defaults to `build/deps/depname/`)
   - `:source` -- where we trigger builds (defaults to `:fetch`)
   - `:build` -- where we have the produced build files (defaults to `<:fetch>/build`)
   - `:deploy` -- where any produced library files should be copied (defaults to same as release executable)
   - `:artifact` -- where output libraries can be found (defaults to `:build`)

If the dependency is directly included in your project (you've specified `:none` as the
`:method` for fetching), then `:source` should be where your Ceedling can find the
source for your dependency in you repo.

All artifacts are relative to the appropriate `:artifact` path. So if there are multiple 
include dirs, choose the highest level and make the rest relative from there. 

Fetching Dependencies
---------------------

The `:dependencies` plugin supports the ability to automatically fetch your dependencies
for you... using some common methods of fetching source. This section contains only a
couple of fields:

- `:method` -- This is the method that this dependency is fetched.
  - `:none` -- This tells Ceedling that the code is already included in the project.
  - `:zip` -- This tells Ceedling that we want to unpack a zip file to our source path.
  - `:gzip` -- This tells Ceedling that we want to unpack a gzip file to our source path.
  - `:git` -- This tells Ceedling that we want to clone a git repo to our source path.
  - `:svn` -- This tells Ceedling that we want to checkout a subversion repo to our source path.
  - `:custom` -- This tells Ceedling that we want to use a custom command or commands to fetch the code.
- `:source` -- This is the path or url to fetch code when using the `:zip`, `:gzip` or `:git` method.
- `:tag`/`:branch` -- This is the specific tag or branch that you wish to retrieve (`:git` only, optional).
- `:hash` -- This is the specific SHA1 hash you want to fetch (`:git` only, optional and triggers a deep clone).
- `:revision` -- This is the specific revision you want to fetch (`:svn` only, optional).
- `:executable` -- This is a YAML list of commands to execute when using the `:custom` method

Some notes:

The `:source` location for fetching a `:zip` or `:gzip` file is relative to the `:paths` ↳ `:source`
folder. 

Environment Variables
---------------------

Many build systems support customization through environment variables. By specifying
an array of environment variables, the Dependencies plugin will customize the shell environment 
before calling the build process.

Note that Ceedling’s project configuration includes a top-level `:environment` sections itself.
The top-level `:environment` section is for all of Ceedling. The `:environment` section nested 
within a specific dependency’s configuration is only for the shell environment used to process
that dependency. The format and abilities of the two `:environment` configuration sections are
also different.

Environment variables may be specified in three ways. Let's look at one of each:

```yaml
:dependencies:
  <a dependency configuration>:
    :environment:
      - ARCHITECTURE=ARM9
      - CFLAGS+=-DADD_AWESOMENESS
      - CFLAGS-=-DWASTE
```

In the first example, you see the most straightforward method. The environment variable
`ARCHITECTURE` is set to the value `ARM9`. That's it. Simple.

The next two options modify an existing symbol. In the first one, we use `+=`, which tells
Ceedling to add the define `ADD_AWESOMENESS` to the environment variable `CFLAGS`. The second
tells Ceedling to remove the define `WASTE` from the same environment variable.

There are a couple of things to note here.

First, when adding to a variable, Ceedling has no way of knowing
what delimiter you are expecting. In this example you can see we manually added some whitespace.
If we had been modifying `PATH` instead, we might have had to use a `:` on a unux or `;` on
Windows.

Second, removing an argument will have no effect on the argument if that argument isn't found
precisely. It's case sensitive and the entire string must match. If symbol doesn't already exist,
it WILL after executing this command... however it will be assigned to nothing.

Building Dependencies
---------------------

The heart of the `:dependencies` plugin is the ability for you, the developer, to specify the
build process for each of your dependencies. You will need to have any required tools installed
before using this feature.

The steps are specified as an array of strings. Ceedling will execute those steps in the order
specified, moving from step to step unless an error is encountered. By the end of the process,
the artifacts should have been created by your process... otherwise an error will be produced.

Artifacts
---------

These are the outputs of the build process. There are there types of artifacts. Any dependency
may have none or some of these. Calling out these files tells Ceedling that they are important.
Your dependency's build process may produce many other files... but these are the files that
Ceedling understands it needs to act on.

### `static_libraries`

Specifying one or more static libraries will tell Ceedling where it should find static libraries
output by your build process. These libraries are automatically added to the list of dependencies
and will be linked with the rest of your code to produce the final release.

If any of these libraries don't exist, Ceedling will trigger your build process in order for it
to produce them.

### `dynamic_libraries`

Specifying one or more dynamic libraries will tell Ceedling where it should find dynamic libraries
output by your build process. These libraries are automatically copied to the same folder as your
final release binary.

If any of these libraries don't exist, Ceedling will trigger your build process in order for it
to produce them.

### `includes`

Often when libraries are built, the same process will output a collection of includes so that
your release code knows how to interact with that library. It's the public API for that library.
By specifying the directories that will contain these includes (don't specify the files themselves,
Ceedling only needs the directories), Ceedling is able to automatically add these to its internal
include list. This allows these files to be used while building your release code, as well we making
them mockable during unit testing.

### `source`

It's possible that your external dependency will just produce additional C files as its output.
In this case, Ceedling is able to automatically add these to its internal source list. This allows
these files to be used while building your release code.

Tasks
=====

Once configured correctly, the `:dependencies` plugin should integrate seamlessly into your
workflow and you shouldn't have to think about it. In the real world, that doesn't always happen.
Here are a number of tasks that are added or modified by this plugin.

### `ceedling dependencies:clean`

This can be issued in order to completely remove the dependency from its source path. On the
next build, it will be refetched and rebuilt from scratch. This can also apply to a particular
dependency. For example, by specifying `dependencies:clean:DepName`.

### `ceedling dependencies:fetch`

This can be issued in order to fetch each dependency from its origin. This will have no effect on
dependencies that don't have fetch instructions specified. This can also apply to a particular
dependency. For example, by specifying `dependencies:fetch:DepName`.

### `ceedling dependencies:make`

This will force the dependencies to all build. This should happen automatically when a release
has been triggered... but if you're just getting your dependency configured at this moment, you
may want to just use this feature instead. A single dependency can also be built by specifying its
name, like `dependencies:make:MyTunaBoat`.

### `ceedling dependencies:deploy`

This will force any dynamic libraries produced by your dependencies to be copied to your release
build directory... just in case you clobbered them.

### `paths:include`

Maybe you want to verify that all the include paths are correct. If you query Ceedling with this
request, it will list all the header file paths that it's found, including those produced by
dependencies.

### `files:include`

Maybe you want to take that query further and actually get a list of ALL the header files
Ceedling has found, including those belonging to your dependencies.

Custom Tools
============

You can optionally specify a compiler, assembler, and linker, just as you would a release build:

```yaml
:tools:
  :deps_compiler:
    :executable: gcc
    :arguments:
      - -g
      - -I"$": COLLECTION_PATHS_SUBPROJECTS
      - -D$: COLLECTION_DEFINES_SUBPROJECTS
      - -c "${1}"
      - -o "${2}"
  :deps_linker:
    :executable: ar
    :arguments:
      - rcs
      - ${2}
      - ${1}
```

Then, once created, you can reference these tools in your build steps by using the `:build_lib` symbol instead
of a series of strings to explain all the steps. Ceedling will understand that it should build all the specified
source and/or assembly files into the specified library:

```yaml
:dependencies:
  :deps:
    - :name: CaptainCrunch
      :paths:
        :fetch:    ../cc/
        :source:   ../cc/
        :build:    ../cc/build
        :artifact: ../cc/build
      :fetch:
        :method: :none
      :environment: []
      :build:
        - :build_lib
      :artifacts:
        :static_libraries:
          - release/cc.a
        :dynamic_libraries: []
        :includes: 
          - ./cc.h
      :defines:
        - THESE_GET_USED_DURING_COMPILATION
```

Happy Testing!
