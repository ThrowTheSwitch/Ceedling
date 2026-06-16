# What Is a Partial?

## Slicing and dicing your C code

Ceedling reads your real source and header files, extracts their C contents,
and generates new C files that comprise a Partial.

Ceedling can create two kinds of Partials:

1. A **_Test Partial_** for exposing otherwise inaccessible functions and 
   variables to your test case assertions.
1. A **_Mock Partial_** for mocking otherwise inaccessible functions in your
   source code.

!!! warning "A function cannot be both tested and mocked in the same test file"
    A core restriction of the C language remains. A partialized function cannot
    be both tested and mocked in the same test. Attempting to do so would duplicate
    the function and cause a doubly-defined symbol failure during linking.
    
    We solve this by simply creating two peer test files for the different Partials
    usage scenarios.

When a test file references a Partial, Ceedling excludes the original source
file from that test executable's build. The generated Partial 
source is compiled and linked in place of the original source C.

!!! note "Purpose-specific C language handling"
    Ceedling includes its own custom, purpose-specific lexing for recognizing
    C language elements. This was the best way to handle all cases across
    platforms. This custom lexer even handles many compiler extensions 
    (e.g. Microsoft's `__declspec` and GCC's `__attribute__()`).
    
    On the upside, this approach provides everything Partials need. On the 
    downside, until exercised by a great deal of real world code, this custom 
    C handling will likely have failings and gaps.

## Partials creation step-by-step

When creating a Partial, Ceedling:

1. Runs your source code under test through the preprocessor to:
    1. Handle `#ifdef` blocks and strip comments.
    1. Collect the `#include` directives.
    1. Expand decorator macros (e.g. `STATICINLINE`) in function signatures.
1. Lexes the code under test to collect its individual C language elements
   (e.g. `typedef`s, macros, functions, variables, etc.).
1. Generates a new set of C files in a _partials/_ build directory. The 
   contents of these new files are:
    1. Reconstructed with the `#include` directives from (1) and elements 
       from (2).
    1. Reorganized and slightly altered so the C elements can be accessed by 
       assertions and mocks in your test cases. Functions are stripped of 
       `static` and `inline`. Variables are stripped of `static` and `extern`ed.
1. Structures the test build to omit the original source file from the 
   resulting test executable. Generated Partials are self-sufficient stand-ins 
   for the original C code from which the Partials are derived.
1. Maps the reorganized functions in generated Partials back to the 
   original source module's filepath and line numbers (using GCC's `#line` 
   directive) for correct test coverage reporting.

!!! tip "Walk-through example"
    See [Partials Walk-Through Example](example.md) for a complete end-to-end
    demonstration of Test Partials and Mock Partials.

## Generated files

| Partial | Purpose | Generated filename pattern |
|---|---|---|
| Testable header | <ul><li>Declares functions</li><li>`extern`s variables</li></ul> | `ceedling_partial_<module>_impl.h` |
| Testable source | <ul><li>Defines functions</li><li>Defines `static`-less variables</li></ul> | `ceedling_partial_<module>_impl.c` |
| Mockable header | <ul><li>Declares function signatures</li></ul> | `ceedling_partial_<module>_interface.h` |

Ceedling uses CMock to generate mocks from Partials interface header files
just as it does for any other mockable header files.

!!! danger "Do not directly access generated Partials files"
    You as the test author will never directly interact with generated 
    Partials C files. Do not modify these generated files or 
    incorporate them into your tests except with the accompanying macros.

<br/><br/>
