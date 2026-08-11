# Partials

Partials let a test exercise a C module's `static` functions directly. It does this by extracting chosen functions out of their original file into small generated files a test can compile and mock against.

A `static` function in C is only visible inside its own file. Nothing outside that file can call it, and nothing outside that file can mock it. This is good design for production code, but it leaves a test author unable to reach exactly the functions most in need of focused, isolated testing. Partials solves this by copying selected functions, whole and unmodified, out of their home file and into a small file generated just for one test. Inside that generated file, the functions are no longer `static`. A test can call them, and CMock can mock them, like any other function.

## Where This Fits in a Test Build

Ceedling's test pipeline drives this subsystem through a handful of stages dedicated to Partials. Those stages read a test's Partial configuration, preprocess the real header and source files a test's Partials depend on, and then generate the Partial files themselves. The stage-by-stage view of that pipeline lives in this codebase's `test_invoker/` documentation. This document stays inside the Partials subsystem itself, explaining what happens once those stages hand it a piece of work.

## Choosing Functions With Macros

A test file selects its Partials by writing macros near the top of the file, such as `TEST_PARTIAL_PRIVATE_MODULE(calculator)`. Each macro names a module and a selection mode.

Four selection modes exist, and each answers a different question about where to start. A public mode begins with every one of the module's ordinary, non-`static` functions. A private mode begins with every one of the module's `static` functions instead. An accumulate mode begins with nothing at all. A deduct mode begins with everything, public and private alike.

Starting from a baseline is rarely the whole story, so a second macro, `TEST_PARTIAL_CONFIG` or `MOCK_PARTIAL_CONFIG`, can add or remove specific functions by name. A name written plainly, or with a leading `+`, is an addition. A name written with a leading `-` is a subtraction. An accumulate mode has no baseline to subtract from, so subtractions are not allowed there. A deduct mode already starts with everything, so additions are not allowed there either. Both rules exist because either combination would be a contradiction rather than a meaningful instruction.

A single test file can select both a test side and a mock side for the same module, or for two different modules entirely. It is common, for example, to test a module's public functions directly while mocking one of its private helpers, all within one test file.

## Reading a Test's Configuration

Before any real C file is touched, a test file's own source text is scanned for these macro calls. Each call is parsed into a small configuration describing, for one module, what its test side and mock side should look like.

This scan enforces a few rules of its own. A `CONFIG` macro must refer to a module already named by an earlier `MODULE` macro, since a configuration with nothing to configure is meaningless. A module's test side or mock side may only be declared once, since declaring it twice would leave two contradictory instructions in place at once. An accumulate mode with no additions at all is also rejected, since it would describe a Partial with nothing in it.

A further round of checks happens later, once the module's real functions are known. Every function named in an addition or a subtraction must genuinely exist in the module. No function may be named as both an addition and a subtraction on the same side. And subtractions on a public or private side must actually match that side's own visibility, since subtracting a private function from a public selection would be removing something that was never there to begin with.

## Extracting the Real Content

Once a module's configuration is known, its real header and source files are located and preprocessed. The preprocessed result is handed to the c_extractor subsystem, which returns a structured picture of every function, variable, and type the module contains. The header's picture and the source's picture are merged into one combined view of the whole module.

Every function in that combined view carries its original line number, traced back through preprocessing to the real file it came from. This traceability matters later, when a generated file needs to point a coverage tool or a debugger back at the function's true home, rather than at the generated file standing in for it.

A further pass reconciles each function's visibility against a fully macro-expanded version of the same file. This second pass exists because a project can hide `static` behind a macro of its own, such as `#define PRIVATE static`. A file preprocessed only far enough to preserve macros cannot see through that indirection. A fully expanded file can.

## Promoting Function-Scoped Statics

C allows a `static` variable to live inside a single function, retaining its value between calls while staying invisible to the rest of the file. Once that function is copied into a generated Partial file, this kind of variable becomes a problem. It needs a home at module scope in the new file, with a name that cannot collide with anything else.

Partials solves this by renaming the variable to something unique, built from the function's name and the variable's own name, and moving its declaration out to module scope in the generated file. Inside the function body, the original declaration is replaced with a harmless no-op, and every reference to the old name is rewritten to the new one. The no-op is written so the total line count of the function does not change, keeping line numbers and coverage data lined up correctly. A test author reaches a promoted variable through a small macro of its own, letting a test read or reset the variable between calls without needing to know the generated name directly.

## Deciding What's Tested and What's Mocked

With the module's content extracted, and its configuration validated, the functions are split into two lists. One list holds the functions destined to be tested directly, complete with their bodies. The other holds the functions destined to be mocked, needing only their signatures.

A module often has typedefs and struct definitions that both lists would otherwise need to repeat. Rather than duplicate that content, and risk defining the same type twice in one test file, it is written once to a shared types file. Both the testable file and the mockable file then include that shared file instead of restating its contents.

A function can never appear on both lists at once. Being directly tested means its real body is compiled into the test. Being mocked means the linker expects a mock in its place instead. These two things cannot both be true of the same function in the same test, so this case is rejected outright.

## Writing the Generated Files

Once both lists are settled, the actual files are written to disk. A tested module gets an implementation header and source. A mocked module gets an interface header, in the same shape CMock expects for any other header it mocks. Each promoted function is written with a line marker immediately ahead of it, pointing a coverage tool or a debugger back at the function's real, original location rather than at the generated file holding it.
