# Partials

A _Partial_ is your C code sliced and diced to expose elements for testing 
that you could not otherwise access without rewriting your source code. 
Think of Partials as a unit testing scalpel.

Partials are useful when you need to test:

* **`static` or `inline` functions** — These become accessible to 
  your test code without modifying your source.
* **File-scoped `static` variables** — The `static` keyword is stripped, 
  and the variable is automatically made `extern` for your test code 
  with no changes to the source under test.
* **Function-scoped `static` variables** — These are promoted from
  function scope to module scope so they can be accessed in your
  test code just like file-scoped `static` variables.
* **Same-module mocked functions** — You can mix and match tested and 
  mocked functions from the same source module. Partials allow mocking 
  functions inside a module that are called by other functions inside 
  the same module.
  
!!! tip
    See the [`wondrous_forest`](../../getting-started/example-projects/wondrous-forest.md) 
    example available within Ceedling for a working example project 
    demonstrating Partials in action.

---

<div class="grid cards" markdown>

-   :material-magnify: **[What Is a Partial?][overview]**

    ---

    How Ceedling generates testable and mockable Partials from your C source
    under test with a step-by-step simple example.

-   :material-format-list-text: **[Conventions & Terminology][conventions]**

    ---

    What is a _module_? _“Public”_ and _“private”_ functions in a programming
    language that has no such terminology.

-   :material-cog: **[Configuration][configuration]**

    ---

    How to enable Partials in your project, include `ceedling.h`, and an
    overview of directive macro categories.

-   :material-school: **[Walk-Through Example][example]**

    ---

    A complete end-to-end demonstration of Test Partials and Mock Partials.

-   :material-pound: **[Partial Directive Macros][directives]**

    ---

    * Generation macros used with `#include` for creating Partials.
    * Config macros for fine-tuning your Partials.

-   :material-variable: **[Accessing Static Variables][variables]**

    ---

    How to test file-scoped and function-scoped `static` variables 
    via Partials.

</div>

!!! warning "Limitations of Partials"
    Partials are new to Ceedling with 1.1.0. Carving up C code is tricky
    business. Complex code _may_ break Ceedling’s lexing or certain assumptions.
    Some issues may be [bugs to be reported](../../help.md) while others may 
    be complexities that Partials are simply unable to resolve.


[overview]:        overview.md
[conventions]:     conventions.md
[directives]:      directives.md
[variables]:       variables.md
[configuration]:   configuration.md
[example]:         example.md

<br/><br/>
