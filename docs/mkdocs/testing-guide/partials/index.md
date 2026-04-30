# Partials

A _Partial_ is your C code sliced and diced to expose functional elements 
for testing that you could not otherwise access without rewriting your 
source code. Think of Partials as a scalpel for testing your code.

Partials are useful when a module under test contains:

* **`static` or `inline` functions** — With Partials these become easily 
  accessible within your test code.
* **File-scoped `static` variables** — With Partials the `static` keyword 
  is stripped and the variable is automatically made `extern` so it can 
  be easily accessed within your test code.
* **Function-scoped `static` variables** — Partials promotes these from
  within function scope to module scope so they can be accessed in your
  test code. Apart from a necessary renaming, these work identically to
  file-scoped `static` variables.

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

-   :material-pound: **[Partial Directive Macros][directives]**

    ---

    * Generation macros used with `#include` for creating Partials.
    * Config macros for fine-tuning your Partials.

-   :material-variable: **[Accessing Static Variables][variables]**

    ---

    How to test file-scoped and function-scoped `static` variables 
    via Partials.

</div>

[overview]:     overview.md
[conventions]:  conventions.md
[directives]:   directives.md
[variables]:    variables.md
