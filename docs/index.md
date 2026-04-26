
# Ceedling

All code is copyright © 2010-2025 Ceedling Project
by Michael Karlesky, Mark VanderVoord, and Greg Williams.

This Documentation is released under a
[Creative Commons 4.0 Attribution Share-Alike Deed][CC4SA].

[CC4SA]: https://creativecommons.org/licenses/by-sa/4.0/deed.en

# Quick Start

Ceedling is a fancypants build system that greatly simplifies building 
C projects. While it can certainly build release targets, it absolutely 
shines at running unit test suites.

## Steps

Below is a quick overview of how to get started from Ceedling installation 
through running build tasks. Jump down just a teeny bit to see what the Ceedling 
command line looks like and navigate to all the documentation for the steps 
listed immediately below.

1. Install Ceedling
1. Create a project
   * Use Ceedling to generate an example project, or
   * Add a Ceedling project file to the root of an existing project, or
   * Create a project from scratch:
      1. Create a project directory
      1. Add source code and optionally test code however you'd like it organized
      1. Create a Ceedling project file in the root of your project directory
1. Run Ceedling tasks from the working directory of your project

Ceedling requires a command line C toolchain be available in your path. It's 
flexible enough to work with most anything on any platform. By default, Ceedling 
is ready to work with [GCC] out of the box (we recommend the [MinGW] project 
on Windows).

A common build strategy with tooling other than GCC is to use your target 
toolchain for release builds (with or without Ceedling) but rely on Ceedling + 
GCC for test builds (more on all this [here][overview]).

[GCC]: https://gcc.gnu.org
[MinGW]: http://www.mingw.org/

## Ceedling Command Line & Build Tasks

Once you have Ceedling installed, you always have access to `ceedling help`.

And, once you have Ceedling installed, you have options for project creation
using Ceedling's application commands:

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

## Quick Start Documentation

* [Installation][quick-start-1]
* [Sample test code file + Example Ceedling projects][quick-start-2]
* [Simple Ceedling project file][quick-start-3]
* [Ceedling at the command line][quick-start-4]
* [All your Ceedling project configuration file options][quick-start-5]

[quick-start-1]: installation.md
[quick-start-2]: test-guide.md#commented-sample-test-file
[quick-start-3]: overview.md#simple-sample-project-file
[quick-start-4]: command-line.md
[quick-start-5]: configuration-reference.md

<br/>

---

# Documentation Overview

(Be sure to review **[breaking changes](https://github.com/ThrowTheSwitch/Ceedling/blob/main/docs/BreakingChanges.md)** if you are working with
a new release of Ceedling.)

Building test suites in C requires much more scaffolding than for
a release build. As such, much of Ceedling's documentation is concerned
with test builds. But, release build documentation is here too. We promise.
It's just all mixed together.

1. **[Ceedling, a C Build System for All Your Mad Scientisting Needs][overview]**

   This section provides lots of background, definitions, and links for Ceedling
   and its bundled frameworks. It also presents a very simple, example Ceedling
   project file.

1. **[Ceedling, Unity, and CMock's Testing Abilities][overview]**

   This section speaks to the philosophy of and practical options for unit testing
   code in a variety of scenarios.

1. **[How Does a Test Case Even Work?][test-guide]**

   A brief overview of what a test case is and several simple examples illustrating
   how test cases work.

1. **[Commented Sample Test File][test-guide]**

   This sample test file illustrates how to create test cases as well as many of the
   conventions that Ceedling relies on to do its work. There's also a brief 
   discussion of what gets compiled and linked to create an executable test.

1. **[Anatomy of a Test Suite][test-guide]**

   This documentation explains how a unit test grows up to become a test suite.

1. **[Ceedling Installation & Set Up][installation]**

   This one is pretty self explanatory.

1. **[Now What? How Do I Make It _GO_? The Command Line.][command-line]**

   Ceedling's command line.

1. **[Important Conventions & Behaviors][conventions]**

   Much of what Ceedling accomplishes — particularly in testing — is by convention. 
   Code and files structured and named in certain ways trigger sophisticated 
   Ceedling build features. This section explains all such conventions.

   This section also covers essential high-level behaviors and features including 
   how to work with search paths, directory structures & file extensions, release 
   build binary artifacts, build time logging, and Ceedling's abilities to 
   preprocess certain code files before they are incorporated into a test build.

1. **[Using Unity, CMock & CException][frameworks]**

   Not only does Ceedling direct the overall build of your code, it also links 
   together several key tools and frameworks. Those can require configuration of 
   their own. Ceedling facilitates this.

1. **[How to Load a Project Configuration. You Have Options, My Friend.][configuration-loading]**

   You can use a command line flag, an environment variable, or rely on a default
   file in your working directory to load your base configuration.

   Once your base project configuration is loaded, you have **_Mixins_** for merging 
   additional configuration for different build scenarios as needed via command line, 
   environment variable, and/or your project configuration file.

1. **[The Almighty Ceedling Project Configuration File (in Glorious YAML)][configuration-reference]**

   This is the exhaustive documentation for all of Ceedling's project file 
   configuration options — from project paths to command line tools to plugins and
   much, much more.

1. **[Which Ceedling][which-ceedling]**

   Sometimes you may need to point to a different Ceedling to run.

1. **[Build Directive Macros][build-directives]**

   These code macros can help you accomplish your build goals When Ceedling's 
   conventions aren't enough.

1. **[Ceedling Plugins][plugins]**

   Ceedling is extensible. It includes a number of built-in plugins for code coverage,
   test report generation, continuous integration reporting, test file scaffolding 
   generation, sophisticated release builds, and more.

1. **[Global Collections][global-collections]**

   Ceedling is built in Ruby. Collections are globally available Ruby lists of paths,
   files, and more that can be useful for advanced customization of a Ceedling project 
   file or in creating plugins.

[overview]:                overview.md
[test-guide]:              test-guide.md
[installation]:            installation.md
[command-line]:            command-line.md
[conventions]:             conventions.md
[frameworks]:              frameworks.md
[configuration-loading]:   configuration-loading.md
[configuration-reference]: configuration-reference.md
[which-ceedling]:          which-ceedling.md
[build-directives]:        build-directives.md
[plugins]:                 plugins/index.md
[global-collections]:      global-collections.md

---

<br/>
