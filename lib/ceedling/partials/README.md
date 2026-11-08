# Partials

Partials allow a test to exercise a C module’s features in ways otherwise impossible. Partials copies selected functions and variables, whole and unmodified, out of their home source file and into a file generated just for one test. These functions and variables are stripped of decorators `static` and `inline` allowing a test to access the variables, call the functions, and CMock to mock the functions like any other. This not only allows access to functions that previously required source rewrites, but it also allows mocking of individual functions inside a module instead of mocking all functions in a header file. The generated file also carries what the selected functions rely on, such as prototypes of functions defined elsewhere and helpers the module header defines, so the selection compiles and links on its own.

See the detailed documentation for using Partials in `docs/mkdocs/testing-guide/partials/`. This documentation discusses Partials' implementation.

## Where This Fits in a Test Build

Ceedling’s test pipeline drives this subsystem through a handful of stages dedicated to Partials. Those stages read a test’s Partial configuration, preprocess the real header and source files that a test’s Partials depend on, and then generate the Partial files themselves. The stage-by-stage view of that pipeline lives in this codebase’s `test_invoker/` documentation. 

## Choosing Functions With Macros

A test file selects its Partials through macros typically located near the top of the file, such as `TEST_PARTIAL_PRIVATE_MODULE(calculator)`. Each macro names a module and a selection mode.

Four selection modes exist, and each answers a different question about where to start. A public mode begins with every one of the module’s ordinary, non-`static` functions. A private mode begins with every one of the module’s `static` functions instead. An accumulate mode begins with nothing at all. A deduct mode begins with everything, public and private alike.

A second macro, `TEST_PARTIAL_CONFIG` or `MOCK_PARTIAL_CONFIG`, can add or remove specific functions by name to the list the macros described above create. A name written plainly, or with a leading `+`, is an addition. A name written with a leading `-` is a subtraction. An accumulate mode has no baseline to subtract from, so subtractions are not allowed there. A deduct mode already starts with everything, so additions are not allowed there either. Both rules exist because either combination would be a contradiction rather than a meaningful instruction.

A single test file can select both a test side and a mock side for the same module, or for two different modules entirely. It is common, for example, to test a module’s public functions directly while mocking one of its private helpers, all from within one test file.

## Reading a Test’s Configuration

Before any real C file is touched, a class called `PartializerConfig` scans a test file’s own source text for the macro calls discussed in the previous section. It works in three passes. The first pass reads every `MODULE` macro and starts a `PartializerConfig::Config` record for each module it names. The second pass reads every `CONFIG` macro and fills in that module’s additions and subtractions. The third pass checks everything the first two passes built. Each `Config` record describes, for one module, what its Partialized test side and mock side should contain. The records describing a module’s files and functions live in a shared module called `Partials`, alongside the rest of this subsystem’s common vocabulary.

This scan enforces a few rules of its own. A `CONFIG` macro must refer to a module already named by an earlier `MODULE` macro, since a configuration with nothing to configure is meaningless. A module’s test side or mock side may only be declared once, since declaring it twice would leave two contradictory instructions in place at once. An accumulate mode with no additions at all is also rejected, since it would describe a Partial with nothing in it.

A further round of checks happens later, once the module’s real functions are known. Every function named in an addition or a subtraction must genuinely exist in the module. No function may be named as both an addition and a subtraction on the same side. And subtractions on a public or private side must actually match that side’s own visibility, since subtracting a private function from a public selection would be removing something that was never there to begin with.

## Extracting the Real Content

Once a module’s configuration is known, a class called `Partializer` locates its real header and source files and hands them off for preprocessing. The preprocessed result is then handed to the c_extractor subsystem, which returns a structured picture of every function, variable, and type the module contains. The header’s picture and the source’s picture are merged into one combined view of the whole module.

Each file is extracted on its own before the merge, so every function and variable can record where it came from. `CModule#stamp_origin!` marks each one `:header` or `:source`. The extractor reads text alone and cannot know a file’s role, so `Partializer` stamps it. Deciding what a Partial carries depends on that origin.

A second class, `PartializerHelper`, finishes preparing that combined view. It traces every function back to its original line number, following it through preprocessing to the real file it came from. It locates every declaration too, searching the original file’s own text so that no included header’s lines are mistaken for it. This traceability matters later, when a generated file needs to point a coverage tool, a debugger, or a compiler message back at the true home of what it holds, rather than at the generated Partial standing in for it. `PartializerHelper` leans on a lower layer of its own, `PartializerUtils`, for the actual text work this requires.

`PartializerHelper` also reconciles each function’s visibility against a fully macro-expanded version of the same file. This second pass exists because a project can hide `static` behind a macro of its own, such as `#define PRIVATE static`. A file preprocessed only far enough to preserve macros cannot see through that indirection. A fully expanded file can. Declarations take their decorators and stripped signature from the expanded file, while keeping the signature as written. Definitions keep their expanded body alongside the original, where a call hidden inside a macro becomes visible.

Splitting a signature into its decorators and the rest removes only storage-class and function-specifier keywords, such as `static`, `inline`, `extern`, and `_Noreturn`. Every other word before the function name belongs to the return type and keeps its place, qualifiers and type keywords included.

## Promoting Function-Scoped Statics

C allows a `static` variable to live inside a single function, retaining its value between calls while staying invisible to the rest of the file. Once that function is copied into a generated Partial file, this kind of variable becomes a problem. It needs a home at module scope in the new file, with a name that cannot collide with anything else.

`PartializerHelper` solves this by renaming the variable to something unique, built from the function’s name and the variable’s own name, and moving its declaration out to module scope in the generated file. Inside the function body, the original declaration is replaced with a harmless no-op, and every reference to the old name is rewritten to the new one. `PartializerUtils` supplies the actual no-op and renaming primitives this work is built from. The no-op is written so the total line count of the function does not change, keeping line numbers and coverage data lined up correctly. A test author reaches a promoted variable through a small macro of its own, letting a test read or reset the variable between calls without needing to know the generated name directly.

## Deciding What’s Tested and What’s Mocked

With the module’s content extracted, and its configuration validated, `Partializer` splits the functions into two lists. One list holds `FunctionDefinition` records for the functions destined to be tested directly, each complete with its body. The other holds `FunctionDeclaration` records for the functions destined to be mocked, each needing only its signature. Both record shapes live in the shared `Partials` module.

A function the module only declares can be mocked, since a mock needs only a signature. An `inline` function the module only declares is the exception. Its body lives in a header the module includes, which a mock cannot replace, so it never becomes a mock candidate.

A module often has `typedef`s and struct definitions that both lists would otherwise need to repeat. Rather than duplicate that content, and risk defining the same type twice in one test file, it is written once to a shared types file. Both the testable file and the mockable file then include that shared file relying on its internal `#include` guards instead of restating its contents.

A function can never appear in both lists at once. Being directly tested means its real body is compiled into the test. Being mocked means the linker is provided a mock in its place instead. These two things cannot both be true of the same function in the same test, so this case is rejected outright.

## Carrying What the Selected Functions Rely On

A Partial’s implementation source carries more than the selected functions. The module’s code relied on prototypes of functions defined elsewhere, and on small `static` or `inline` helpers its header defines. Without them, selected code fails to compile, or an `extern inline` function never gets its external definition. `PartializerHelper#plan_carry` decides what comes along, and `Partializer#plan_carry` logs that decision.

The decision is made per function name, from facts extraction already recorded. Those facts are whether the module defines a body for the name, whether the test selected it, which file each item came from, and its reconciled storage class. Each name falls into one category.

- **Selected to test or to mock.** Nothing more is carried. The selection is written as before.
- **External.** The module declares the function but never defines it. A prototype that is not `static` is carried when kept code uses the name. An `inline` prototype is carried regardless, since its job is to make this file hold the function’s external definition.
- **Header helper.** Every body for the name sits in the module header and is `static` or `inline`. The body and its prototypes are carried when kept code uses it.
- **Left out.** Any other unselected body. Prototypes that are neither `static` nor `inline` are carried when kept code uses the name, so a test stub for a subtracted function links.

Kept code is the selected bodies, the variables and macro invocations the implementation source writes, and each helper already carried. Each is scanned once for the names it uses. Code uses any name it holds, so a callback passed by name counts as surely as a call. A body is read from its expanded copy, where a macro’s call is visible. Its own parameters and local variables are taken away, since they only share a name with any function. Literals and comments are blanked first, and member accesses and struct, union and enum tags are dropped, so a field or a type sharing a function’s name never counts. Under fallback preprocessing, macro definitions count as kept code too, since expansion is unreliable there. Helpers are followed transitively, and the prototypes are decided once the helpers are known. Nothing is carried unless something uses it, so carrying never forces unneeded code to compile, nor puts a prototype where a later header’s macro could mangle it.

Two rules hold helpers back. A module header without an include guard cannot be stood in for, so the real header may still arrive through another include, helpers and all. Its referenced helpers are skipped and named in a notice. Fallback preprocessing can also leave two different copies of one name. Carrying both would fail to compile, so neither is carried and a notice names the function.

The result is a `Partials::CarryPlan`. It holds the carried prototypes, the carried helpers by name, and the skipped names, each with a one-line reason. Prototypes are indexed by object identity, since the generator later walks the very declarations the plan chose. `Partializer#plan_carry` then locates each carried prototype in its original file’s own text, reading each file once, so its `#line` can name the right file and line.

The plan also names each `extern` variable whose struct or union type the module never completes. No definition of such a variable compiles, weak or not. `Partializer#plan_carry` looks for the type’s completing definition in the module’s files and in their raw directives-only copies, which hold every header each file includes.

## Writing the Generated Files

Once both lists are settled, a separate class named `GeneratorPartials` writes the actual files to disk. It lives outside this directory, alongside Ceedling’s other file-writing classes, deliberately kept apart from the classes that decide what belongs in a Partial. A tested module gets an implementation header and source. A mocked module gets an interface header, in the same shape CMock expects for any other header it mocks. Each promoted function is written with a line marker (`#line`) immediately ahead of it, pointing a coverage tool or a debugger back at the function’s real, original location rather than at the generated file holding it.

The implementation source also writes the carry plan. It walks the module’s items in their original order after every include, so a carried item sees each header the module’s code saw, the module’s own mock interface included. `GeneratorPartials` decides what each item is, and a `PartialSourceWriter` writes it. The writer keeps the state that spans items: an open run of prototypes, the file a `#line` last named, and the line count of the file so far.

A carried prototype is written as the user spelled it, behind a `#line` naming its original file and line. A run of carried prototypes sits inside GCC diagnostic pragmas that quiet `-Wredundant-decls`, unless `:partials` ↳ `:suppress_redundant_decls` is off. A carried helper is written as its header wrote it, anchored with `#line` like a selected body. After any located item, a `#line` hands attribution back to the generated file before the next item without a location of its own. Every `#line` path uses forward slashes, since a backslash in its string starts an escape sequence. Nothing carried is written to a header, so the test file and runner compile exactly what the selection gives them.

Variables follow two rules of their own. The implementation header writes one `extern` declaration per variable name, taken from the variable’s definition when the module has one, so an array keeps its size. A variable the module only declares `extern` lives elsewhere. Under `:partials` ↳ `:extern_variables`, the implementation source gives it one weak definition that a real one overrides (`:weak`, the default), or none at all (`:test`). A variable of a type the module never completes gets no definition either way.

## Regenerating Partials

A delta build writes a Partial’s files again only when something generation reads has changed. The three generated files of a module share one record of those inputs:

- The module’s original header and source, and the preprocessed copies of each that extraction parses. The copies connect generation to preprocessing. Whatever rewrites them, such as forced fallback preprocessing or a different preprocessor, regenerates the Partial. An unchanged rebuild rewrites nothing.
- The test’s selection for the module: each side’s selection mode, additions, and subtractions.
- The include list of each generated file, which depends on the test’s other Partial modules and how each is selected.
- The real header’s include guard, which every generated file spoofs.
- The preprocessing flags, defines, and search paths, and the project’s `:partials` settings.

The code that composes Partials is not among these inputs. A Ceedling upgrade that changes what Partials contain leaves existing generated files in place until the build is clobbered.
