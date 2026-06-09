# Testing Guide

!!! danger "Test file naming in Windows"
    **_Test filenames should not include “patch” or “setup”_**.
    Test filenames become test executables. Windows Installer Detection 
    Technology (part of UAC) requires administrator privileges to run 
    executables with this naming.

## Test Cases & Test Suites

<div class="grid cards" markdown>

-   :material-help-circle: **[How Does a Test Case Even Work?][test-cases]**

    ---

    A brief overview of how test cases work with simple examples illustrating
    assertions and mocks.

-   :material-file-code: **[Commented Sample Test File][test-sample]**

    ---

    A sample test file illustrating the Ceedling conventions that make it go. 
    Includes a discussion of what gets compiled and linked into a test executable.

-   :material-layers: **[Anatomy of a Test Suite][test-suite-anatomy]**

    ---

    How a unit test grows up to become a test suite — what a test executable
    is, why there are multiple, and Ceedling’s role in building and running them.

</div>

## Testing with Ceedling

<div class="grid cards" markdown>

-   :material-book-open-page-variant: **[Important Conventions & Behaviors][conventions]**

    ---

    Much of what Ceedling accomplishes is by convention. Code and file structures 
    and naming trigger sophisticated test build features. Also covers search paths, 
    file extensions, preprocessing, and more.

-   :material-link-variant: **[Using Unity & CMock][frameworks]**

    ---

    Ceedling connects the Unity and CMock frameworks — each of which 
    can require configuration of its own. Ceedling facilitates this.

-   :material-content-cut: **[Partials][partials]**

    ---

    Partials are like a scalpel for your source code. A generated partial allows 
    you to test and mock parts of your code you could not otherwise access
    without rewriting it first.

-   :material-pound: **[Build Directive Macros][build-directives]**

    ---

    In-test macros to accomplish build goals when Ceedling’s conventions aren’t
    quite enough — adding source files, handling include paths, and more.

</div>

[test-cases]:         test-cases.md
[test-sample]:        test-sample.md
[test-suite-anatomy]: test-suite-anatomy.md
[conventions]:        conventions.md
[frameworks]:         frameworks.md
[build-directives]:   build-directives.md
[partials]:           partials/index.md

<br/><br/>
