# Partials

A _Partial_ is your C code sliced and diced to expose elements for testing 
that you could not otherwise access without rewriting your source code. 
Think of Partials as a unit testing scalpel.

Partials are useful when a module under test contains:

* **`static` or `inline` functions** — These become accessible within 
  your test code.
* **File-scoped `static` variables** — The `static` keyword is stripped, 
  and the variable is automatically made `extern` for easy access within 
  your test code.
* **Function-scoped `static` variables** — These are promoted from
  function scope to module scope so they can be accessed in your
  test code. Apart from necessary renaming, this works identically to
  file-scoped `static` variables.

!!! warning "Limitations of Partials"
    Partials are new to Ceedling with 1.1.0. Carving up C code is tricky
    business. Complex code _may_ break Ceedling’s lexing or its assumptions 
    on symbol ordering. Some issues may be [bugs to be reported](../../help.md) 
    while others may be complexities that Partials are simply unable to resolve.

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

[overview]:        overview.md
[conventions]:     conventions.md
[directives]:      directives.md
[variables]:       variables.md
[configuration]:   configuration.md
[example]:         example.md

<br/><br/>
