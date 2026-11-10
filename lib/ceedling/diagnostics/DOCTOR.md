# The Build Step Doctor

The build step doctor explains a failed build step to the test developer. When a test's compilation or linking fails, the doctor reads the tool's output and the inputs it ran with, recognizes failures with a known cause, and logs guidance beside the tool's own error. The error is still raised, so the guidance only adds to it.

## Why it exists

Some toolchain errors have causes that only Ceedling's conventions explain. A redeclaration error can mean a mocked header's real content reached the compilation a second way. A missing symbol most often means a test's `#include` directives left out a source it needs. A duplicate symbol can mean a mock was linked beside the source it stands in for. The raw error names none of this. A developer reading only the compiler's words may spend a long time finding a cause Ceedling could have pointed to.

Each kind of guidance follows the same pattern:

1. **Match the output.** The failed step's output shows a known error, in any of the wordings different toolchains use.
2. **Examine the case.** The step's inputs, such as the test's mocks, its search paths, the headers its `.d` file lists, or the objects it linked, confirm the cause applies. Each case that applies writes its own guidance, so one failure can draw several.

The doctor holds that pattern once. Each kind of guidance is a small diagnosis written against it.

## The mechanism

`BuildStepDoctor` (`build_step_doctor.rb`) is the engine. It knows nothing about Ceedling. Specialists hold the knowledge, and the doctor gathers their diagnoses once, in `setup`.

- **`Diagnosis`** is a struct a specialist builds. It has a `name`, the `steps` it covers (`:preprocess`, `:compile`, `:link`), the `outcomes` it covers (`:failure` by default, or `:warning`), its `symptoms`, and its `examination`.
- **Symptoms** are a Regexp, or an Array of them with one per toolchain family. Any match makes the case a candidate.
- **The examination** is a callable that takes a `Case` and returns a prescription (a String), several (an Array), or nil when the case turns out not to be its own.
- **`Case`** holds the `step`, the `outcome`, the tool's `output`, the `symptoms` MatchData, and the step's `inputs` Hash.
- **`BuildStepDoctor#diagnose(step:, output:, inputs:, outcome: :failure)`** runs every diagnosis whose steps, outcomes, and symptoms fit, in the order the specialists were composed. It logs each prescription at `Verbosity::ERRORS` with `LogLabels::NOTICE`, and returns them.

An examination that raises is a bug in guidance, never a reason to hide a build's real failure. The doctor logs the error at DEBUG and runs the remaining diagnoses. A step or outcome the doctor doesn't know raises `ArgumentError`, at `setup` or at `diagnose`, so a typo can't silently disable a diagnosis.

`ToolchainOutput` (`toolchain_output.rb`) reads the header and object paths an output mentions. A path is any token ending in a wanted extension, quoted or not, so one reader serves every location format below. A stray match is harmless, because each specialist compares paths against files it already knows.

### Specialists

| Specialist | Step | Diagnoses |
|---|---|---|
| `HeaderCollisionSpecialist` | compilation | `:substituted_header_collision`: a header the test mocks or Partializes collides with its own real content. `:shared_directory_collision`: a header collides in a directory it shares with other headers, none of them substituted (see `test_invoker/HEADER_COLLISIONS.md`). |
| `MissingSymbolSpecialist` | linking | `:missing_symbols`: a symbol no linked object defines. |
| `DuplicateSymbolSpecialist` | linking | `:duplicate_symbols`: a symbol more than one linked object defines. The guidance names a mock linked beside the source it stands in for. |

`TestSubstitutions` (`test_invoker/test_substitutions.rb`) answers two questions both sibling-header isolation and the collision diagnoses ask: which real headers a test substitutes, and which directories hold Ceedling's own generated content.

### Where the doctor is connected

`TestBuildExecutor` calls the doctor from two places, each just before it raises the failure:

- **`compile_test_component`**, for a C compilation, with `tool`, `source`, `object`, `search_paths`, `flags`, `defines`, `testable`, and `dependencies`. `dependencies` is the first attempt's `.d` file, whose paths are the real headers, even when an isolated retry produced the failure.
- **`generate_executable`**, for a link, with `tool`, `objects`, `executable`, `flags`, `lib_args`, `lib_paths`, and `testable`.

Compilation and linking failures are where guidance helps a test developer most. Preprocessing isn't connected. Ceedling runs the preprocessor many times per test, and several runs are expected to fail and fall back by design. Useful guidance is harder to draw from those failures, and a misplaced prescription there would only add noise. Assembly and release builds aren't connected either. The engine accepts a `:preprocess` step and a `:warning` outcome, so connecting more needs only a call site.

### Sharing the doctor without a lock

Every compilation thread in a test build shares one doctor. That needs no lock, because the doctor fixes its diagnoses in `setup` and `diagnose` only reads them. Specialists keep no state between examinations either. Adding a diagnosis after `setup`, or giving a specialist mutable state, would break this guarantee.

The doctor composes its specialists, rather than each specialist registering itself, because DIY builds an object only when something references it.

## Adding a diagnosis

1. Add a `Diagnosis` to an existing specialist's `diagnoses`, or write a new specialist and compose it into `build_step_doctor` in `objects.yml`.
2. Give it symptoms for each toolchain family you can, ending in a generic net. Err toward matching, since the examination decides whether the case applies.
3. Write its examination against the `Case` inputs. Return nil when the inputs show the cause doesn't apply.
4. Write its prescription in the shared shape:
   - a tentative opening, such as "The linker output appears to report…", since no matcher reads every toolchain perfectly;
   - a blank line, then a heading such as `HOW THIS HAPPENS:` over `•` bullets on the C mechanics, mentioning Ceedling only briefly;
   - a blank line, then `OPTIONS:` over a numbered list of ways to resolve the problem;
   - every line left-justified, so a narrow terminal wraps it cleanly. The loginator turns `•` into `*` when decorators are off.
5. Cover it in a unit spec under `spec/units/diagnostics/`, with one case per wording, and in `spec/integration/build_step_doctor_spec.rb` when a real compiler can produce the failure.

## Known toolchain wordings

Each table lists what the symptoms match, family by family. The evidence column states how each wording is known:

- **real toolchain:** produced by a real compiler or linker in `spec/integration/build_step_doctor_spec.rb`, which runs on GCC 14, Apple Clang 15, and CI's compilers;
- **vendor forums:** quoted from build logs posted in vendor support forums;
- **expected:** the toolchain's documented message format, not yet observed in this project.

### Collisions at compilation

| Family | Wordings | Evidence |
|---|---|---|
| GCC | `redefinition of`, `redeclaration of`, `conflicting types for`, `previous definition of`, `previous declaration of`, `redeclared as different kind of symbol` | real toolchain |
| Clang, armclang, Microchip XC8 v2 and later | `redefinition of`, `typedef redefinition with different types`, `previous definition is here`, `conflicting types for` | real toolchain (Clang) |
| IAR | `Error[Pe101]: … has already been declared in the current scope`, `Pe147` `declaration is incompatible with`, `Pe256` `invalid redeclaration of type name` | vendor forums (Pe101), expected (Pe147, Pe256) |
| Arm armcc | `Error: #101: … has already been declared in the current scope` | vendor forums |
| TI, Green Hills | `error #101`, `error #147`, `error #256`, with the EDG texts above | expected |
| MSVC | `C2011` type redefinition, `C2084` function already has a body, `C2370` and `C2371` `redefinition; different` | expected |
| TASKING, SDCC, others | generic: `redefin`, `redeclar`, `already declared`, `already defined`, `duplicate definition`, `duplicate declaration` | expected |

Header paths are read in each location format: `a.h:12:3` (GCC, Clang), `"a.h",12` (IAR), `"a.h", line 12` (Arm armcc, TI, Green Hills), `a.h(12)` (MSVC), and prose such as `declared at line 5 of "a.h"`.

### Missing symbols at link time

| Family | Wordings | Evidence |
|---|---|---|
| GNU ld, Microchip XC16 and XC32 | `undefined reference to` | real toolchain (CI's Linux jobs) |
| Apple ld | `Undefined symbols for architecture`, `symbol(s) not found` | real toolchain |
| LLD | `undefined symbol:` | expected |
| MSVC | `LNK2019`, `LNK2001`, `unresolved external symbol` | expected |
| IAR ILINK | `Error[Li005]: no definition for` | vendor forums |
| Arm armlink | `Error: L6218E: Undefined symbol` | vendor forums |
| TI | `undefined first referenced` table header, `unresolved symbols remain` | vendor forums |
| Green Hills, TASKING, SDCC, others | generic: `undefined global`, `undefined external`, `unresolved external`, `unresolved symbol` | expected |

### Duplicate symbols at link time

| Family | Wordings | Evidence |
|---|---|---|
| GNU ld | `multiple definition of`, `first defined here` | real toolchain (CI's Linux jobs) |
| Apple ld | `duplicate symbol` | real toolchain |
| LLD | `duplicate symbol:` | expected |
| MSVC | `LNK2005` `already defined in`, `LNK1169` | expected |
| IAR ILINK | `Error[Li006]: duplicate definitions for` | vendor forums |
| Arm armlink | `Error: L6200E: Symbol … multiply defined` | vendor forums |
| TI | `error #10056: symbol … redefined: first defined in` | vendor forums |
| Green Hills, TASKING, SDCC, others | generic: `multiple definition`, `multiply defined`, `duplicate symbol`, `duplicate definition`, `already defined` | expected |
