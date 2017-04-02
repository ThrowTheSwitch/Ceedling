Ceedling - Build/test system for C based on Ruby/Rake
=====================================================

[![Ceedling Build Status](https://api.travis-ci.org/ThrowTheSwitch/Ceedling.png?branch=master)](https://travis-ci.org/ThrowTheSwitch/Ceedling)

Ceedling is a build system for C projects that is something of an extension around Ruby’s Rake (make-ish) build system. Ceedling also makes TDD (Test-Driven Development) in C a breeze by integrating [CMock](https://github.com/throwtheswitch/cmock), [Unity](https://github.com/throwtheswitch/unity), and [CException](https://github.com/throwtheswitch/cexception) -- three other awesome open-source projects you can’t live without if you're creating awesomeness in the C language. Ceedling is also extensible with a handy plugin mechanism.

Usage Documentation
===================

Documentation and license info exists [in the repo in docs/](docs/CeedlingPacket.md)

Getting Started (Developers)
============================

First make sure Ruby is installed on your system (if it's not already). Then, from a command prompt:

    > gem install ceedling

(Alternate Installation for Those Planning to Be Ceedling Developers)
======================================================================

    > git clone --recursive https://github.com/throwtheswitch/ceedling.git
    > cd ceedling
    > bundle install # Ensures you have all RubyGems needed
    > bundle exec rake # Run all CMock library tests

If bundler isn't installed on your system or you run into problems, you might have to install it:

    > sudo gem install bundler

Pulling Ceedling inside a Project
=================================

Ceedling can deploy all of its guts into a folder. This allows it
to be used without having to worry about external dependencies.
You don't have to worry about Ceedling changing for this particular
project just because you updated your gems.

    ceedling new YourNewProjectName

This will install all of Unity, CMock, and Ceedling into a new folder
named YourNewProjectName. It will also create a simple directory structure
for you with src and test folders. SCORE! It's also creates a simple
rakefile and project.yml file that you can tweak to your own needs.

It'll also include documentation for all of these tools, unless you
specify --nodocs at when you issue the command above... then it skips
that step for you.

Using Ceedling From A Ruby Gem
==============================

Ceedling can also be used as a gem. By installing it this way, you
can automatically update to the latest version of Ceedling, Unity,
and CMock just by running an update on your gems. Use this if you
are only running one project OR if you feel you want to keep all
your projects up to date.

    ceedling new YourNewProjectName --as_gem

This creates a new folder named YourNewProjectName. Inside it will be your
shiny new project file, rakefile, and a couple of src and test directories
to get you started. You can then tweak all of those things to your heart's
content.

