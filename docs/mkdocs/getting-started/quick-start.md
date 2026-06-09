# Quick Start

## Handy Documentation

* [Installation](installation.md)
* [Sample test code file](../testing-guide/test-sample.md)
* [Example Ceedling projects](../testing-guide/test-sample.md#ceedling-includes-example-projects)
* [Simple Ceedling project file](../overview/build-system.md#simple-sample-project-file)
* [Ceedling at the command line](command-line.md)
* [All your project configuration file options](../configuration/index.md)

---

## Quick Start Steps

Below is a quick overview of how to get started from Ceedling installation 
through running build tasks. Jump down just a teeny bit to see what the Ceedling 
command line looks like and navigate to all the documentation for the steps 
listed immediately below.

1. [Install Ceedling](installation.md)
1. Create a project
    * Use Ceedling to generate an example project (see next section), or
    * Add a Ceedling project file to the root of an existing project, or
    * Create a project from scratch:
        1. Create a project directory.
        1. Add source code and optionally test code however you’d like it organized.
        1. Create a Ceedling project file in the root of your project directory.
1. Run Ceedling tasks (see next section) from the working directory of your project.

!!! note
    Ceedling requires a command line C toolchain be available in your path. It’s 
    flexible enough to work with most anything on any platform. By default, Ceedling 
    is ready to work with [GCC] out of the box (we recommend the [MinGW] project 
    on Windows).

A common build strategy with tooling other than GCC is to use your target 
toolchain for release builds—with or without Ceedling—but rely on Ceedling + 
GCC for test builds (more on all this [here][overview]).

[GCC]: https://gcc.gnu.org
[MinGW]: http://www.mingw.org/
[overview]: ../overview/index.md

## Command Line & Build Tasks

Once you have Ceedling installed, you always have access to `ceedling help`.

Once you have Ceedling installed, you have options for project creation
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

<br/><br/>
