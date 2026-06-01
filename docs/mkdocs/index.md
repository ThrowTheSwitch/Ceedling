# Ceedling Packet

Ceedling is a fancypants build system that greatly simplifies building 
C projects. While it can certainly build release targets, it absolutely 
shines at running unit test suites.

Ceedling and its suite of frameworks, including Unity and CMock, were developed 
for use on platforms from heavy duty workstations to teeny tiny microcontrollers. 
Features handy for low-level development have made these tools popular with 
embedded systems developers.

!!! tip "New to Ceedling?"
    <img src="assets/images/ceedling.svg" width="130"><br/>
    Jump straight to the [Quick Start][quick-start] — installation,
    project set up, and your first build tasks all in one place.

!!! feature "New in Ceedling 1.1.0 — Partials"
    A [_Partial_](testing-guide/partials/index.md) is your C code sliced and diced
    to expose functional elements for testing that you could not otherwise 
    access without rewriting your source code. Think of Partials as a scalpel 
    for testing your code.

## Overview

<div class="grid cards" markdown>

-   :material-hammer-wrench: **[A Build System for C][build-system]**

    ---

    Generate a complete test and release build from a single YAML file.
    Provides a minimal sample project configuration and an explanation of Ceedling’s
    design philosophy.

-   :material-toolbox: **[Tools & Frameworks][tools-and-frameworks]**

    ---

    Ruby, Rake, YAML, Unity, CMock, and CException explained — the pieces that make
    Ceedling possible and how they fit together.

-   :material-test-tube: **[Test Environments][test-environments]**

    ---

    Native host builds, emulator-based runs, and on-target execution — choose the
    right test suite strategy for your project.

</div>

## Getting Started

<div class="grid cards" markdown>

-   :material-rocket-launch: **[Quick Start][quick-start]**

    ---

    Ready to go? Let’s go.

-   :material-download: **[Ceedling Installation & Set Up][installation]**

    ---

    Installing Ceedling and its prerequisites.

-   :material-console: **[Ceedling’s Command Line.][command-line]**

    ---

    Now what? How do I make it _Go_?

</div>

## Unit Testing

<div class="grid cards" markdown>

-   :material-help-circle: **[How Does a Test Case Even Work?][test-cases]**

    ---

    A brief overview of what a test case is with simple examples illustrating
    how test cases work.

-   :material-file-code: **[Commented Sample Test File][test-sample]**

    ---

    A sample test file illustrating test case creation and the conventions
    that make it work. Includes a discussion of how test executables get built.

-   :material-layers: **[Anatomy of a Test Suite][test-suite-anatomy]**

    ---

    How a unit test grows up to become a test suite.

-   :material-link-variant: **[Using Unity, CMock & CException][frameworks]**

    ---

    Ceedling links together Unity, CMock, and CException — each of which can
    require configuration of their own. Ceedling facilitates this.

-   :material-book-open-page-variant: **[Important Conventions & Behaviors][conventions]**

    ---

    Much of testing in Ceedling is accomplished by convention.
    Code and files structured and named in certain ways trigger sophisticated build
    features.

-   :material-content-cut: **[Partials][partials]**

    ---

    Partials are like a scalpel for your source code. A generated partial allows 
    you to test and mock parts of your code you could not otherwise access
    without rewriting it first.
</div>

## Project Configuration

<div class="grid cards" markdown>

-   :material-file-import: **[How to Load a Project Configuration][configuration-loading]**

    ---
    You have options, my friend. Load your base configuration via command line 
    flag, environment variable, or default file. Add Mixins to merge configuration 
    for different build scenarios.

-   :material-file-cog: **[The Mighty Project Configuration File][configuration-project-file]**

    ---

    Everything you need to know about the project configuration file. All in 
    glorious YAML.

-   :material-book-open-variant: **[Project Configuration Reference][configuration-reference]**

    ---

    Exhaustive documentation for all project configuration options — project
    paths, testing features, plugins, and much more.

-   :material-clipboard-play-multiple-outline: **[Parallel Builds][parallel-builds]**

    ---

    Configure Ceedling to take advantage of multiple CPU cores for faster build
    steps and test suite execution.

-   :material-directions-fork: **[Which Ceedling?][which-ceedling]**

    ---

    Sometimes you may need to point to a different Ceedling to run.

</div>

## Advanced & Extending

<div class="grid cards" markdown>

-   :material-pound: **[Build Directive Macros][build-directives]**

    ---

    Code macros to accomplish build goals when Ceedling's conventions aren't
    quite enough.

-   :material-puzzle-plus: **[Ceedling Plugins][plugins]**

    ---

    Ceedling is extensible with built-in plugins for code coverage, test reporting,
    CI integration, file scaffolding, sophisticated release builds, and more.

-   :material-database: **[Global Collections][global-collections]**

    ---

    Globally available Ruby lists of paths, files, and more — useful for advanced
    project customization and plugin development.

</div>

[quick-start]:                 getting-started/quick-start.md
[build-system]:                overview/build-system.md
[tools-and-frameworks]:        overview/tools-and-frameworks.md
[testing-abilities]:           overview/testing-abilities.md
[test-environments]:           overview/test-environments.md
[test-cases]:                  testing-guide/test-cases.md
[test-sample]:                 testing-guide/test-sample.md
[test-suite-anatomy]:          testing-guide/test-suite-anatomy.md
[partials]:                    testing-guide/partials/index.md
[installation]:                getting-started/installation.md
[command-line]:                getting-started/command-line.md
[conventions]:                 testing-guide/conventions.md
[frameworks]:                  testing-guide/frameworks.md
[configuration-loading]:       configuration/loading.md
[configuration-project-file]:  configuration/project-file.md
[configuration-reference]:     configuration/reference/index.md
[parallel-builds]:             configuration/parallel-builds.md
[which-ceedling]:              configuration/which-ceedling.md
[build-directives]:            testing-guide/build-directives.md
[plugins]:                     plugins/index.md
[global-collections]:          configuration/global-collections.md

<br/><br/>
