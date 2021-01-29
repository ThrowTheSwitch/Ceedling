Ceedling ![CI](https://github.com/ThrowTheSwitch/Ceedling/workflows/CI/badge.svg)
========
Ceedling is a build system for C projects that is something of an extension 
around Ruby’s Rake (make-ish) build system. Ceedling also makes TDD (Test-Driven Development) 
in C a breeze by integrating [CMock](https://github.com/throwtheswitch/cmock), 
[Unity](https://github.com/throwtheswitch/unity), and 
[CException](https://github.com/throwtheswitch/cexception) -- 
three other awesome open-source projects you can’t live without if you're creating awesomeness 
in the C language. Ceedling is also extensible with a handy plugin mechanism.

Usage Documentation
===================

Documentation and license info exists [in the repo in docs/](docs/CeedlingPacket.md)

Getting Started
===============

First make sure Ruby is installed on your system (if it's not already). Then, from a command prompt:

    > gem install ceedling

(Alternate Installation for Those Planning to Be Ceedling Developers)
======================================================================

    > git clone --recursive https://github.com/throwtheswitch/ceedling.git
    > cd ceedling
    > bundle install # Ensures you have all RubyGems needed
    > git submodule update --init --recursive # Updates all submodules
    > bundle exec rake # Run all Ceedling library tests

If bundler isn't installed on your system or you run into problems, you might have to install it:

    > sudo gem install bundler

If you run into trouble running bundler and get messages like this `can't find gem
bundler (>= 0.a) with executable bundle (Gem::GemNotFoundException)`, you may
need to install a different version of bundler. For this please reference the
version in the Gemfile.lock. An example based on the current Gemfile.lock is as
followed:

    > sudo gem install bundler -v 1.16.2

Creating A Project
==================

Creating a project with Ceedling is easy. Simply tell ceedling the
name of the project, and it will create a subdirectory called that
name and fill it with a default directory structure and configuration.

    ceedling new YourNewProjectName

You can add files to your src and test directories and they will
instantly become part of your test build. Need a different structure?
You can start to tweak the `project.yml` file immediately with your new
path or tool requirements.

You can upgrade to the latest version of Ceedling at any time,
automatically gaining access to the packaged Unity and CMock that
come with it.

    gem update ceedling

Documentation
=============

Are you just getting started with Ceedling? Maybe you'd like your
project to be installed with some of its handy documentation? No problem!
You can do this when you create a new project.

    ceedling new --docs MyAwesomeProject

Bonding Your Tools And Project
==============================

Ceedling can deploy all of its guts into the project as well. This
allows it to be used without having to worry about external dependencies.
You don't have to worry about Ceedling changing for this particular
project just because you updated your gems... no need to worry about
changes in Unity or CMock breaking your build in the future. If you'd like
to use Ceedling this way, tell it you want a local copy when you create
your project:

    ceedling new --local YourNewProjectName

This will install all of Unity, CMock, and Ceedling into a new folder
named `vendor` inside your project `YourNewProjectName`. It will still create
the simple directory structure for you with `src` and `test` folders.

SCORE!

If you want to force a locally installed version of Ceedling to upgrade
to match your latest gem later, it's easy! Just issue the following command:

    ceedling upgrade --local YourNewProjectName

Just like the `new` command, it's called from the parent directory of your
project.

Are you afraid of losing all your local changes when this happens? You can keep
Ceedling from updating your project file by issuing `no_configs`.

    ceedling upgrade --local --no_configs TheProject

Git Integration
===============

Are you using Git? You might want to automatically have Ceedling create a
`gitignore` file for you by adding `--gitignore` to your `new` call.

*HAPPY TESTING!*
