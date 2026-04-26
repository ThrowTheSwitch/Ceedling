# Ceedling, a C Build System for All Your Mad Scientisting Needs

Ceedling allows you to generate an entire test and release build 
environment for a C project from a single, short YAML configuration 
file.

Ceedling and its bundled tools, Unity, CMock, and CException, don't 
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

From the command line, to run all your unit tests, you would run 
`ceedling test:all`. To build the release version of your project,
you would simply run `ceedling release`. That's it!

Of course, many more advanced options allow you to configure
your project with a variety of features to meet a variety of needs.
Ceedling can work with practically any command line toolchain
and directory structure – all by way of the configuration file.

See this [commented project file][example-config-file] 
for a much more complete and sophisticated example of a project 
configuration.

See the later [configuration section][project-configuration] for 
way more details on your project configuration options.

A facility for [plugins](plugins/index.md) also allows you to 
extend Ceedling's capabilities for needs such as custom code metrics 
reporting, build artifact packaging, and much more. A variety of 
built-in plugins come with Ceedling.

[example-config-file]: snapshot/assets/project.yml
[project-configuration]: configuration/index.md

## What's with This Name?

Glad you asked. Ceedling is tailored for unit tested C projects and is built
upon Rake, a Make replacement implemented in the Ruby scripting language.

So, we've got C, our Rake, and the fertile soil of a build environment in which
to grow and tend your project and its unit tests. Ta da — _Ceedling_.

Incidentally, though Rake was the backbone of the earliest versions of
Ceedling, it is now being phased out incrementally in successive releases
of this tool. The name Ceedling is not going away, however!

## What Do You Mean "Tailored for unit tested C projects"?

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
[`subprojects`](plugins/subprojects.md) plugin can 
accomplish quite a bit here).

It's quite common and entirely workable to host Ceedling and your 
test suite alongside your existing release build setup. That is, you 
can use make, Visual Studio, SCons, Meson, etc. for your release build
and Ceedling for your test build. Your two build systems will simply
"point" to the same project code.

## Hold on. Back up. Ruby? Rake? YAML? Unity? CMock? CException?

Seems overwhelming? It's not bad at all. And, for the benefits testing
bring us, it's all worth it.

### Ruby

[Ruby] is a handy scripting language like Perl or Python. It's a modern, 
full featured language that happens to be quite handy for accomplishing 
tasks like code generation or automating one's workflow while developing 
in a compiled language such as C.

[Ruby]: http://www.ruby-lang.org/en/

### Rake

[Rake] is a utility written in Ruby for accomplishing dependency 
tracking and task automation common to building software. It's a modern, 
more flexible replacement for [Make].

Rakefiles are Ruby files, but they contain build targets similar
in nature to that of Makefiles (but you can also run Ruby code in
your Rakefile).

[Rake]: http://rubyrake.org/
[Make]: http://en.wikipedia.org/wiki/Make_(software)

### YAML

[YAML] is a "human friendly data serialization standard for all
programming languages." It's kinda like a markup language but don't
call it that. With a YAML library, you can [serialize] data structures
to and from the file system in a textual, human readable form. Ceedling
uses a serialized data structure as its configuration input.

YAML has some advanced features that can greatly 
[reduce duplication][yaml-anchors-aliases] in a configuration file 
needed in complex projects. YAML anchors and aliases are beyond the scope
of this document but may be of use to advanced Ceedling users. Note that 
Ceedling does anticipate the use of YAML aliases. It proactively flattens 
YAML lists to remove any list nesting that results from the convenience of
aliasing one list inside another.

[YAML]: http://en.wikipedia.org/wiki/Yaml
[serialize]: http://en.wikipedia.org/wiki/Serialization
[yaml-anchors-aliases]: https://blog.daemonl.com/2016/02/yaml.html

### Unity

[Unity] is a [unit test framework][unit-testing] for C. It provides facilities
for test assertions, executing tests, and collecting / reporting test
results. Unity derives its name from its implementation in a single C
source file (plus two C header files) and from the nature of its
implementation - Unity will build in any C toolchain and is configurable
for even the very minimalist of processors.

[Unity]: http://github.com/ThrowTheSwitch/Unity
[unit-testing]: http://en.wikipedia.org/wiki/Unit_testing

### CMock

[CMock]<sup>†</sup> is a tool written in Ruby able to generate [function mocks & stubs][test-doubles] 
in C code from a given C header file. Mock functions are invaluable in 
[interaction-based unit testing][interaction-based-tests].
CMock's generated C code uses Unity.

<sup>†</sup> Through a [plugin][FFF-plugin], Ceedling also supports
[FFF], _Fake Function Framework_, for [fake functions][test-doubles] as an
alternative to CMock's mocks and stubs.

[CMock]: http://github.com/ThrowTheSwitch/CMock
[test-doubles]: https://blog.pragmatists.com/test-doubles-fakes-mocks-and-stubs-1a7491dfa3da
[FFF]: https://github.com/meekrosoft/fff
[FFF-plugin]: plugins/fff.md
[interaction-based-tests]: http://martinfowler.com/articles/mocksArentStubs.html

### CException

[CException] is a C source and header file that provide a simple
[exception mechanism][exn] for C by way of wrapping up the
[setjmp / longjmp][setjmp] standard library calls. Exceptions are a much
cleaner and preferable alternative to managing and passing error codes
up your return call trace.

[CException]: http://github.com/ThrowTheSwitch/CException
[exn]: http://en.wikipedia.org/wiki/Exception_handling
[setjmp]: http://en.wikipedia.org/wiki/Setjmp.h

## Notes on Ceedling Dependencies and Bundled Tools

* By using the preferred installation option of the Ruby Ceedling gem (see 
  later installation section), all other Ceedling dependencies will be 
  installed for you.

* Regardless of installation method, Unity, CMock, and CException are bundled 
  with Ceedling. Ceedling is designed to glue them all together for your 
  project as seamlessly as possible.

* YAML support is included with Ruby. It requires no special installation
  or configuration. If your project file contains properly formatted YAML
  with the recognized names and options (see later sections), you are good 
  to go.

<br/>

# Ceedling, Unity, and CMock's Testing Abilities

The unit testing Ceedling, Unity, and CMock afford works in practically 
any context.

The simplest sort of test suite is one crafted to run on the same host 
system using the same toolchain as the release artifact under development.

But, Ceedling, Unity, and CMock were developed for use on a wide variety 
of systems and include features handy for low-level system development work.
This is especially of interest to embedded systems developers.

## All your sweet, sweet test suite options

Ceedling, Unity, and CMock help you create and run test suites using any 
of the following approaches. For more on this topic, please see this 
[handy dandy article][tts-which-build] and/or follow the links for each 
item listed below.

[tts-which-build]: https://throwtheswitch.org/build/which

1. **[Native][tts-build-native].** This option builds and runs code on your 
   host system.
   1. In the simplest case this means you are testing code that is intended
      to run on the same sort of system as the test suite. Your test 
      compiler toolchain is the same as your release compiler toolchain.
   1. However, a native build can also mean your test compiler is different
      than your release compiler. With some thought and effort, code for
      another platform can be tested on your host system. This is often
      the best approach for embedded and other specialized development.
1. **[Emulator][tts-build-cross].** In this option, you build your test code with your target's
   toolchain, and then run the test suite using an emulator provided for
   that target. This is a good option for embedded and other specialized
   development — if an emulator is available.
1. **[On target][tts-build-cross].** The Ceedling bundle of tools can create test suites that
   run on a target platform directly. Particularly in embedded development
   — believe it or not — this is often the option of last resort. That is,
   you should probably go with the other options in this list.

[tts-build-cross]: https://throwtheswitch.org/build/cross 
[tts-build-native]: https://throwtheswitch.org/build/native

<br/>
