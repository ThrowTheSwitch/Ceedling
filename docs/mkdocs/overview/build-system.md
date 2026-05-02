# A Build System for All Your C Mad Scientisting Needs

Ceedling allows you to generate an entire test and release build 
environment for a C project from a single, short YAML configuration 
file. It truly shines at supporting unit testing and managing test 
builds.

Ceedling and its bundled frameworks, Unity, CMock, and CException, don't 
want to brag, but they're also quite adept at supporting the tiniest of 
embedded processors, the beefiest 64-bit powerhouses available, and 
everything in between.

Assembling build environments for C projects — especially with
automated unit tests — is a pain. No matter the all-purpose build 
environment tool you use, configuration is tedious and requires 
considerable glue code to pull together the necessary tools and 
libraries to run unit tests. The Ceedling bundle handles all this 
for you.

## Simple Sample Project File

For a project including Unity/CMock unit tests and using the default 
toolchain `gcc`, the configuration file could be as simple as this:

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

!!! tip "Want to see a real world project configuration?"
    See this [commented project file][example-config-file] 
    for a much more complete and sophisticated example of a project 
    configuration.

From the command line, to run all your unit tests, you would run 
`ceedling test:all`. To build the release version of your project,
you would simply run `ceedling release`. That's it!

Of course, many more advanced options allow you to configure
your project with a variety of features to meet a variety of needs.
Ceedling can work with practically any command line toolchain
and directory structure – all by way of the configuration file.

See the later [configuration section][project-configuration] for 
way more details on your project configuration options.

A facility for [plugins](../plugins/index.md) also allows you to 
extend Ceedling's capabilities for needs such as custom code metrics 
reporting, build artifact packaging, and much more. A variety of 
built-in plugins come with Ceedling.

[example-config-file]: ../snapshot/assets/project.yml
[project-configuration]: ../configuration/index.md

## What's with this name?

Glad you asked. Ceedling is tailored for unit tested C projects and is built
upon Rake, a Make replacement implemented in the Ruby scripting language.

So, we've got C, our Rake, and the fertile soil of a build environment in which
to grow and tend your project and its unit tests. Ta da — _Ceedling_.

Incidentally, though Rake was the backbone of the earliest versions of
Ceedling, it is now being phased out incrementally in successive releases. 
The name Ceedling is not going away, however!

## “Tailored for unit-tested C projects”?

Well, we like to write unit tests for our C code to make it lean and
mean — that whole [Test-Driven Development][tdd] thing.

Along the way, this style of writing C code spawned two
tools to make the job easier:

1. A unit test framework for C called _Unity_
1. A mocking library called _CMock_

And, though it's not directly related to testing, a C framework for 
exception handling called _CException_ also came along.

[tdd]: http://en.wikipedia.org/wiki/Test-driven_development

These tools and frameworks are great, but they require quite
a bit of environment support to pull them all together in a convenient,
usable fashion. We started off with Rakefiles to assemble everything.
These ended up being quite complicated and had to be hand-edited
or created anew for each new project. Ceedling replaces all that
tedium and rework with a configuration file that ties everything
together.

Though Ceedling is tailored for unit testing, it can also go right 
ahead and build your final binary release artifact for you as well. 
That said, Ceedling is more powerful as a unit test build environment 
than it is a general purpose release build environment. Complicated 
projects including separate bootloaders or multiple library builds, 
etc. are not necessarily its strong suit (but the 
[`subprojects`](../plugins/subprojects.md) plugin can 
accomplish quite a bit here).

It's quite common and entirely workable to host Ceedling and your 
test suite alongside your existing release build setup. That is, you 
can use make, Visual Studio, SCons, Meson, etc. for your release build
and Ceedling for your test build. Your two build systems will simply
"point" to the same project code.
