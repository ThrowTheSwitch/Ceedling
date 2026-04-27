!!! tip "New to Ceedling?"
    Jump straight to the [Quick Start](quick-start.md) — installation,
    project set up, and your first build tasks all in one place.

---

# Ceedling Packet

!!! warning "Upgrading Ceedling?"
    Be sure to review [breaking changes](https://github.com/ThrowTheSwitch/Ceedling/blob/master/docs/BreakingChanges.md).

## Overview

<div class="grid cards" markdown>

-   **[A C Build System for All Your Mad Scientisting Needs][overview]**

    ---

    Background, definitions, and links for Ceedling and its bundled frameworks.
    Includes a simple example project file.

-   **[Ceedling, Unity, and CMock’s Testing Abilities][overview]**

    ---

    Philosophy and practical options for unit testing C code in a variety of scenarios.

</div>

## Getting Started

<div class="grid cards" markdown>

-   **[Ceedling Installation & Set Up][installation]**

    ---

    Installing Ceedling and its prerequisites.

-   **[Ceedling’s Command Line.][command-line]**

    ---

    Now what? How do I make it _Go_?

</div>

## Unit Testing

<div class="grid cards" markdown>

-   **[How Does a Test Case Even Work?][test-cases]**

    ---

    A brief overview of what a test case is with simple examples illustrating
    how test cases work.

-   **[Commented Sample Test File][test-sample]**

    ---

    A sample test file illustrating test case creation and the conventions
    that make it work. Includes a discussion of how test executables get built.

-   **[Anatomy of a Test Suite][test-suite-anatomy]**

    ---

    How a unit test grows up to become a test suite.

-   **[Using Unity, CMock & CException][frameworks]**

    ---

    Ceedling links together Unity, CMock, and CException — each of which can
    require configuration of their own. Ceedling facilitates this.

-   **[Important Conventions & Behaviors][conventions]**

    ---

    Much of testing in Ceedling is accomplished by convention.
    Code and files structured and named in certain ways trigger sophisticated build
    features.

</div>

## Project Configuration

<div class="grid cards" markdown>

-   **[How to Load a Project Configuration][configuration-loading]**

    ---
    You have options, my friend. Load your base configuration via command line 
    flag, environment variable, or default file. Add Mixins to merge configuration 
    for different build scenarios.

-   **[The Mighty Project Configuration File][configuration-reference]**

    ---

    Exhaustive documentation for all project file configuration options — project
    paths, command line tools, plugins, and much more. All in glorious YAML.

-   **[Which Ceedling][which-ceedling]**

    ---

    Sometimes you may need to point to a different Ceedling to run.

</div>

## Advanced & Extending

<div class="grid cards" markdown>

-   **[Build Directive Macros][build-directives]**

    ---

    Code macros to accomplish build goals when Ceedling's conventions aren't
    quite enough.

-   **[Ceedling Plugins][plugins]**

    ---

    Ceedling is extensible with built-in plugins for code coverage, test reporting,
    CI integration, file scaffolding, sophisticated release builds, and more.

-   **[Global Collections][global-collections]**

    ---

    Globally available Ruby lists of paths, files, and more — useful for advanced
    project customization and plugin development.

</div>

[overview]:                overview.md
[test-cases]:              testing-guide/test-cases.md
[test-sample]:       testing-guide/test-sample.md
[test-suite-anatomy]:      testing-guide/test-suite-anatomy.md
[installation]:            installation.md
[command-line]:            command-line.md
[conventions]:             testing-guide/conventions.md
[frameworks]:              testing-guide/frameworks.md
[configuration-loading]:   configuration-loading.md
[configuration-reference]: configuration/index.md
[which-ceedling]:          which-ceedling.md
[build-directives]:        testing-guide/build-directives.md
[plugins]:                 plugins/index.md
[global-collections]:      global-collections.md
