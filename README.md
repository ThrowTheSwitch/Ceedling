# 🌱 Ceedling ![CI](https://github.com/ThrowTheSwitch/Ceedling/workflows/CI/badge.svg)

 **Ceedling is a handy-dandy build system for C projects. Ceedling can build your 
release artifact but is especially adept at building test suites.**

Ceedling works the way developers want to work. It is entirely command-line driven.
All generated and framework code is easy to see and understand. Its features
cater to low-level embedded development as well as enterprise-level software 
systems.

Ceedling is the glue for bringing together three other awesome open-source 
projects you can’t live without if you‘re creating awesomeness in the C language.

1. [Unity], an xUnit-style test framework.
1. [CMock], a code generating, function mocking kit for interaction-based testing.
1. [CException], a framework for adding simple exception handling to C projects
   in the style of higher-order programming languages.

In its simplest form, Ceedling can build and test an entire project from just a
few lines in a project configuration file.

Because it handles all the nitty-gritty of rebuilds and becuase of Unity and CMock,
Ceedling makes TDD ([Test-Driven Development][tdd]) in C a breeze.

Ceedling is also extensible with a simple plugin mechanism.

[Unity]: https://github.com/throwtheswitch/unity
[CMock]: https://github.com/throwtheswitch/cmock
[CException]: https://github.com/throwtheswitch/cexception
[tdd]: http://en.wikipedia.org/wiki/Test-driven_development

# 📚 Documentation & Learning

## Ceedling docs

[Usage help][ceedling-packet] (a.k.a. _Ceedling Packet_), [release notes][release-notes], [breaking changes][breaking-changes], a variety of guides, and much more exists in [docs/](docs/).

## Online tutorial

Matt Chernosky’s [detailed tutorial][tutorial] demonstrates using Ceedling to build a full project and C test suite. As the tutorial is a number of years old, the content is a bit out-of-date. That said, it provides an excellent overview of a real project.

## Library and courses

[ThrowTheSwitch.org][TTS] provides a small but useful [library of resources][library] and links to two paid courses, _[Dr. Surly’s School for Mad Scientists][courses]_, that provide in-depth training on writing C unit tests and using Unity, CMock, and Ceedling to do so. 

[ceedling-packet]: docs/CeedlingPacket.md
[release-notes]: docs/ReleaseNotes.md
[breaking-changes]: docs/BreakingChanges.md
[TTS]: https://throwtheswitch.org
[tutorial]: http://www.electronvector.com/blog/add-unit-tests-to-your-current-project-with-ceedling
[library]: http://www.throwtheswitch.org/library
[courses]: http://www.throwtheswitch.org/dr-surlys-school

# ⭐️ Getting Started

**See the 👀_[Quick Start](docs/CeedlingPacket.md#quick-start)_ section in Ceedling’s core documentation, _Ceedling Packet_.**

## The basics

### Direct installation

1. Install [Ruby]. (Only Ruby 3+ supported.)
1. Install Ceedling. (All supporting frameworks are included.)
   ```shell
   > gem install ceedling
   ```
1. Create an empty Ceedling project or add a Ceedling project file to
   the root of your existing project.
1. Run tasks like so:
   ```shell
   > ceedling test:all release
   ```

### Docker image

A fully packaged [Ceedling Docker image][docker-image] containing Ruby, Ceedling, the GCC toolchain, and some helper scripts is also available. A Docker container is portable, well managed, and an alternative to a local installation of Ceedling.

The Ceedling Docker image is early in its lifecycle and due for significant updates and improvements. Check its documentation for version information, status, and supported platforms.

[docker-image]: https://hub.docker.com/r/throwtheswitch/madsciencelab


### Example super-duper simple Ceedling configuration file

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

[Ruby]: https://www.ruby-lang.org/

## Creating a project

Creating a project with Ceedling is easy. Simply tell Ceedling the
name of the project, and it will create a directory with that name
and fill it with a default subdirectory structure and configuration 
file.

```shell
 > ceedling new YourNewProjectName
```

You can add files to your `src/` and `test/` directories, and they will
instantly become part of your test build. Need a different structure?
You can modify the `project.yml` file with your new path or tooling 
setup.

You can upgrade to the latest version of Ceedling at any time,
automatically gaining access to any updates to Unity, CMock, and 
CException that come with it.

```shell
 > gem update ceedling
```

## Documentation

Are you just getting started with Ceedling? Maybe you'd like your
project to be installed with some of its handy [documentation](docs/)? 
No problem! You can do this when you create a new project.

```shell
 > ceedling new --docs MyAwesomeProject
```

## Attaching a Ceedling version to your project

Ceedling can be installed as a globally available Ruby gem. Ceedling can 
also deploy all of its guts into your project instead. This allows it to 
be used without worrying about external dependencies. More importantly, 
you don’t have to worry about Ceedling changing outside of your project 
just because you updated your gems. No need to worry about changes in 
Unity or CMock breaking your build in the future.

To use Ceedling this way, tell it you want a local copy when you create
your project:

```shell
 > ceedling new --local YourNewProjectName
```

This will install all of Unity, CMock, CException, and Ceedling itsef 
into a new folder `vendor/` inside your project `YourNewProjectName/`.
It will still create a simple empty directory structure for you with
`src/` and `test/` folders.

If you want to force a locally installed version of Ceedling to upgrade
to match your latest gem later, no problem. Just do the following:

```shell
 > ceedling upgrade --local YourNewProjectName
```

Just like with the `new` command, an `upgrade` should be executed from 
from within the root directory of your project.

Are you afraid of losing all your local changes when this happens? You 
can prevent Ceedling from updating your project file by adding 
`--no_configs`.

```shell
 > ceedling upgrade --local --no_configs YourSweetProject
```

## Git integration

Are you using Git? You might want Ceedling to create a `.gitignore` 
file for you by adding `--gitignore` to your `new` call.

```shell
 > ceedling new --gitignore YourNewProjectName
```

# 💻 Ceedling Development

## Alternate installation

```shell
 > git clone --recursive https://github.com/throwtheswitch/ceedling.git
 > cd ceedling
 > git submodule update --init --recursive
 > bundle install
```

The Ceedling repository incorporates its supporting frameworks and some
plugins via git submodules. A simple clone may not pull in the latest
and greatest.

The `bundle` tool ensures you have all needed Ruby gems installed. If 
Bundler isn’t installed on your system or you run into problems, you 
might have to install it:

```shell
 > sudo gem install bundler
```

If you run into trouble running bundler and get messages like _can’t 
find gem bundler (>= 0.a) with executable bundle 
(Gem::GemNotFoundException)_, you may need to install a different 
version of Bundler. For this please reference the version in the 
Gemfile.lock.

```shell
 > sudo gem install bundler -v <version in Gemfile.lock>
```

## Running self-tests

Ceedling uses [RSpec] for its tests.

To run all tests run the following from the root of your local 
Ceedling repository.

```shell
 > bundle exec rake
```

To run individual test files and perform other tasks, use the 
available Rake tasks. From the root of your local Ceedling repo,
list those task like this:

```shell
 > rake -T
```

[RSpec]: https://rspec.info