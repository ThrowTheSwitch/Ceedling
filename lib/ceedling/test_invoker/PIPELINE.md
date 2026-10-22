# The Test Build Pipeline

The test pipeline turns a list of test files into compiled, linked, and executed test results. It carries one record per test file through a fixed sequence of stages. Each stage reads what earlier stages found and adds a little more.

Each test file in a run gets its own `Testable` record, and every `Testable` travels together inside one `PipelineState`. A stage sees a test file only through its `Testable` and the whole run only through `PipelineState`. Early stages find out what a test needs: what it `#include`s, what build directives it carries, what mocks and Partials it uses. Later stages do the work: preprocessing, generating mocks and Partials, compiling, linking, and running the test executable. Every stage is visited on every run, and a stage with nothing to do recognizes it and steps aside.

## The pipeline's shape

Nine classes divide the stages, each owning one concern:

- **`TestInvoker`** owns one test build run from start to finish. It opens the dependency cache before the run and flushes it afterward, and fires the `pre_test_build` and `post_test_build` plugin hooks around it. When anything in the pipeline raises, it catches the exception, logs it, and records the run as a failed build. Once a run finishes, it also answers narrow questions such as which sources a test pulled in, for callers that want dependency information rather than a real build.
- **`TestPipelineManager`** owns the stage sequence: the fixed list of stages below, and the feature toggles and stop points that let a stage decline to run. It knows nothing of how a stage does its work, only whether it runs.
- **`TestBuildSetup`** does each test's groundwork in stages 1–3: build directories, the text scan of the test file's `#include`s and build directives, and the flags, defines, and search paths every later stage uses.
- **`TestIncludesExtractinator`** runs stage 4, which replaces the text scan's `#include`s with what the real preprocessor found. It sequences one class per pass: `TestBareIncludesExtractinator`, `TestIncludesPreprocessinator`, and `TestIncludesReconcilinator`.
- **`TestBuildPlanner`** decides what to generate and build: which mocks a test needs, what its runner and Partials will be, and, once everything upstream has run, the final sources, objects, and artifacts to compile and link.
- **`PartialsManager`** preprocesses each Partial's header and source files and generates its implementation, interface, and, when needed, types header, calling on `Partializer` (`lib/ceedling/partials/`) for the C parsing and extraction.
- **`TestFilePreprocessinator`** runs stage 11, which preprocesses each test file and extracts its `TEST_SOURCE_FILE()` directives.
- **`TestRunnerGeneratinator`** runs stages 12 and 13, which parse test case names and generate each test's Unity runner.
- **`TestBuildExecutor`** does the remaining work the planner decided on: generating mocks, compiling objects, linking executables, and running the test fixtures.

The seven stage classes never call each other. `TestPipelineManager` alone sequences them, calling each stage's method on the shared `PipelineState` in turn.

Three collaborators hold logic more than one stage needs, so the stages cannot drift apart:

- **`TestSearchPaths`** composes a test's search paths in the order the compiler searches them, and sets a test's mock search paths (stages 2, 3, and 4).
- **`MockLocator`** resolves a mock's real header and the directory mirroring it below the test's mock root (stages 2, 4, and 5).
- **`StandinHeaderinator`** places stand-in headers for mocks and Partials (stage 4).

## `PipelineState` and `Testable`

`PipelineState` exists once for the whole run, and a `Testable` exists once per test file. Between them they hold everything a stage reads or writes:

- **Identity**: a `Testable`'s `filepath` and `name`, set in the first stage and never changed.
- **Paths and preprocessing scratch state**: where this test's build output, mocks, Partials, and preprocessed files live, and the bookkeeping preprocessing needs along the way. These stay plain Hashes because their keys are sparse and conditional. A project with mocking disabled has no `:mocks` path at all, which a Hash tolerates better than a struct field with no meaningful default.
- **Flags, defines, and search paths**: the compiler, linker, and preprocessor arguments resolved once per test and reused by every stage that runs a tool. `mock_search_paths` holds the part of `search_paths` that points at this test's mirrored mock directories (see [Mock search paths](#mock-search-paths)), so a stage can take them back out when it needs the ordering without them.
- **Generated-content records**: `runner` (a `RunnerInfo`), each resolved mock in `mocks` (a `MockDetails`), and `partials` (a `TestablePartials`, holding a config map and the two lists of module names Partials generation has produced so far). These have a fixed shape every instance shares, which is what a struct is for: a mistyped field name fails loudly instead of silently doing nothing.
- **Build artifacts and results**: the final sources, objects, and executable path a test resolves to, and where its results are written.
- **`isolated_headers_path`**: set the first time stage 15's sibling-header isolation stages something for this test (see `HEADER_COLLISIONS.md`), and nil otherwise. Stage 15 reads it once more at its end to know what to clean up.
- **`executable_rebuilt`**: set by stage 16 and read by stage 17. It is carried rather than re-derived because by the time stage 17 asks, the dependency tracker has already been told the executable is fresh, and asking it again would always answer "no."

`PipelineState` carries the run's list of tests, the Hash of every `Testable`, the run's context and options, a `Mutex` guarding concurrent writes, and four accumulator lists: `partials_headers`, `partials_sources`, `mocks_list`, and `objects_list`. These exist so later stages can hand every Partial file, mock, or object across every test to the parallelism machinery as one flat batch instead of one nested loop per test. Each item in them (`PartialWork`, `MockWork`, `ObjectWork`) is a small struct, for the same reason `RunnerInfo` and `MockDetails` are.

## A test's two `#include` lists

Which mocks, sources, and runner includes a test gets depends on its `#include`s, and the pipeline knows them in two forms. Which one drives a test's build depends on the project's preprocessing.

- **The text-scan list**, from stage 2, reads every `#include` line as written. It strips comments but evaluates no `#if`, so it can't tell that a branch is off, and it can't see an `#include` that a macro names.
- **The reconciled list**, from the end of stage 4, is what the real preprocessor found, following the test file's `#include`s into the headers they name, so a macro a header defines decides an `#if` as it will at compile time. Stage 4 replaces the stored text-scan list with it.

The text-scan list drives the build when test preprocessing is off, with `:use_test_preprocessor` set to `:none` or `:mocks`. Otherwise, from stage 5 on, every stage reads the reconciled list. That includes whole-run fallback mode, when the preprocessor lacks `-fdirectives-only` or `:test_build` ↳ `:preprocess_force_fallback` is set. Stage 4 reconciles there too, but against a plain expansion, and only as a best effort (see [Stage 4's three passes](#stage-4s-three-passes)).

Stages 2 and 3 run before stage 4, so anything they derive from the `#include`s comes from the text-scan list. Anything a later stage relies on must hold for the reconciled list too, and mock search paths are the case that needs care.

## The stages, in order

**Context collection (stages 1-4)** finds out what a test needs, without generating or compiling anything.

- **Stage 1** creates each test's build directories and its `Testable`.
- **Stage 2** scans the test file as text: its `#include`s, its include path build directives (cached between runs), and its Partials configuration. With test preprocessing off, it also scans `TEST_SOURCE_FILE()` directives and test case names, since nothing later will. It checks that the test uses mocks or Partials only where the project enables them, and it collects the test's first mock search paths from the text-scan list.
- **Stage 3** resolves the flags, defines, and search paths every later tool call for this test uses.
- **Stage 4** runs only with test preprocessing on. It extracts the test file's `#include`s through the real preprocessor in three passes, described below, ends by replacing the text-scan list with the reconciled one, and narrows the mock search paths to the mocks that remain.

**Planning (stage 5)** is where `TestBuildPlanner` decides what this test needs generated: which of its includes are mocks and where each one's real header resolves, what its Partials configuration looks like, and where its runner will live. It checks that every header the test includes exists, and it fires the `pre_test` plugin hook. Nothing is generated yet.

**Partials (stages 6-8)** run only when the project uses Partials and this run has any. A transform first flattens every test's Partials configuration into two lists, one of Partial header files and one of Partial source files, so stages 6 and 7 can preprocess every Partial file across every test as one parallel batch. Stage 8 then generates each Partial's implementation and interface from that output.

**Mocks (stages 9-10)** run only when the project uses mocks and this run has any. A transform flattens every test's planned mocks into one list, as the Partials transform does. Stage 9, with mock preprocessing on (`:mocks` or `:all`), preprocesses each header to be mocked. Stage 10 generates each mock's source and header with CMock, into a directory that mirrors its real header's location below the test's mock root. The `:mocking` stop point ends the run here.

Two same-named headers mocked by directory stay distinct through `:cmock` ↳ `:mock_name_include_folder`, on by default. CMock names a mock's include guard and lifecycle functions by the folder its `#include` names, and the runner names its calls by the same `#include`, so the two always agree. `TestBuildExecutor#mock_folder_and_path` hands CMock that folder. When the folder ends the mirrored directory, the mock stays there. An `#include` spelling more path than the mirror holds puts its mock at the written path below the test's mock root instead, which the root search path still reaches.

**Test file preprocessing and runners (stages 11-13)** work on the test file itself. Stages 11 and 12 run only with test preprocessing on. Stage 11 preprocesses the test file and extracts its `TEST_SOURCE_FILE()` directives from the result. Stage 12 parses test case names from that output. Stage 13 always runs and generates the Unity test runner, from the preprocessed test file when there is one and the original otherwise. The `:test_runner` stop point ends the run here.

Each of these stages is skipped when nothing its output is built from has changed, which takes in more than the test file. Stage 11's full expansion reads every header the test reaches, so the project headers named in its line markers are among stage 11's dependencies, as they are for stage 4's second pass. Editing the macro in a header that enables a test case therefore reruns stage 11. When stage 11 is skipped, its `TEST_SOURCE_FILE()` directives are recalled from a cache. Stages 12 and 13 check one runner target. It depends on the test file, the file test case names are parsed from, the runner and Unity configuration, and the test's mock and include lists. With test preprocessing, those lists come from stage 4's reconciliation, so a header that changes which mocks a test has regenerates its runner although the test file is unchanged.

**Artifacts, build, and execution (stages 14-17)** close out the run. Stage 14 resolves each test's final sources, objects, executable path, and results paths. A transform flattens every test's objects into one list so stage 15 can compile them all as a parallel batch. That batch runs in two sequential passes: each test's own file first, fully complete before any other object in that test starts. A test's own compile is where sibling-header isolation (see `HEADER_COLLISIONS.md`) may correct the test's search paths, and every other object must see the correction. Stage 16 links each test's executable, and stage 17 runs each test fixture and collects its results.

A module a Partial has taken over is left out of a test's linked objects, since the Partial's generated source is what links for that module. The original module's source is still compiled at stage 15 like every other source, and only trimmed from the objects handed to the linker at stage 16. Compiling it keeps its dependency tracking working like any other source's. Under coverage tools (`gcov`, Bullseye) it also keeps accurate the `#line` directives that map a Partial's generated code back to the original module, since that mapping holds only if the original module runs through the coverage toolchain's compiler.

## Stage 4's three passes

Stage 4 gets a test file's `#include`s from the real preprocessor, and its three passes build on each other. Each of the first two runs a real preprocessor process and is skipped when the dependency tracker reports nothing relevant changed.

1. **Bare includes** (`TestBareIncludesExtractinator`). GCC runs with `-M -MG` on an isolated copy of the test file, listing the `#include`s it reaches with the test's defines applied. `-MG` lets it list a mock that doesn't exist yet. The list is cached between runs.

   A run that writes no make rule failed as a tool, since errors in the file's own code still leave a rule. Its result is `nil`, logged at obnoxious verbosity with the tool's output. Stage 4 doesn't cache it, so the next run tries again, and an empty list stands in meanwhile.

   The isolated copy can't open any other header, so an `#include` guarded by a macro another header defines evaluates false there and drops out. The test file's literal `#include` lines are therefore added to GCC's list as candidates, as they are for a mockable header (`Preprocessinator#supplement_with_text_includes`). A candidate survives only if the second pass confirms it.

   Stand-ins are placed for every candidate mock and Partial (see [Stand-in headers](#stand-in-headers)). A mock on GCC's list must have a real header. A mock only the text scan found may sit in a branch that is off and name a header that doesn't exist, so it gets no stand-in then. The test's mock search paths are then set from the candidates' mocks.
2. **Preprocessed includes** (`TestIncludesPreprocessinator`). The preprocessor runs over the test file with `-fdirectives-only`, using the test's full search paths. This pass follows `#include`s, through the stand-ins into the headers they name, so it sees what the compile will see. Its output records which `#include`s came from the test file itself. Because the output depends on every file the pass read, the project files its line markers show it entered are registered as its dependencies, as a compile registers its `.d` file, so editing a header the test reaches reruns it. Generated files below the build root, such as stand-ins and mocks, are left out.
3. **Reconciliation** (`TestIncludesReconcilinator`). The user and system `#include`s from pass 2 are checked against the candidates plus any `#include` a macro names, as resolved by pass 2's output (`Preprocessinator#supplement_with_computed_includes`). The result replaces the stored text-scan list, and the mock search paths narrow to the mocks that remain.

   If pass 2 failed for one file, that file's text-scan includes take its place, checked against GCC's list alone. The candidates hold those same text-scan includes, so checking against them would keep every one, including mocks in branches that are off. GCC's list still evaluated those branches. If GCC's list is empty too, nothing is left to check the text scan against. Stage 2's list then stands as it is, the Partial headers its configuration added included. That is a best effort, and mocks in branches that are off stay with it.

   Reconciliation never replaces a non-empty text-scan list with an empty one. An empty result while the test file's text names `#include`s means preprocessing found none it should have. Ingesting it would replace the test's header and source `#include`s at once. Stage 2's list stands instead, and a warning at default verbosity names the file. Configuration validation rejects the usual cause in advance: `-P` and `--no-line-commands`, which drop the line markers pass 2 is read through (see `preprocess/README.md`).

Whole-run fallback mode reconciles as a best effort, with no guarantee that the result matches what the compile will see. Without `-fdirectives-only`, pass 2 runs the full preprocessor tool instead, a plain `-E` expansion (`Preprocessinator#generate_fallback_expansion_output`). A plain expansion keeps no macros, but its line markers still name every file it entered. Pass 3 reads those markers as it reads directives-only output, computed `#include`s included. The expansion is cached and tracked as directives-only output is.

A few details keep the two modes apart. The `MODES` table in `TestIncludesPreprocessinator` holds what differs: tool, output path, generator, and testable key. The expansion lives under the test's `fallback_expansion/` directory, apart from stage 11's own full expansion. It keeps the test file's name, since the line-marker reader finds the test file's own lines by that name. Its path is recorded in `testable.preprocess[:fallback_expansion]`, while `[:directives_only]` stays nil, so stage 11 still preprocesses the test file its fallback way. A test file whose expansion fails takes the per-file path above.

One shape still escapes: an `#include` of a mock that a macro from another header names. Neither pass 1 nor the text scan can find its file name, so no stand-in exists for it, and pass 2 fails on it.

### Stand-in headers

A stand-in is a file placed where a test's mock or Partial header will later be generated. The preprocessor needs something to find at each mocked or Partialized `#include` before stage 8 or stage 10 has produced the real file. A stand-in sits exactly where the real file will: a mock's mirrors its real header's directory below the test's mock root, a Partial mock's follows its own `#include`'s path below that root, and a Partial's follows the directory its generated `#include` names.

A mock's stand-in includes the mock's real header, the line CMock opens the generated mock with (`:orig_header_include_fmt` around the header's name). A macro the header defines is then visible to pass 2 through the stand-in, as it will be through the real mock. A Partial's stand-in is blank. Every stand-in starts with a marker line that tells it apart from a real mock.

Pass 1 places stand-ins whether its list was just extracted or recalled from cache, since a cached list says nothing about whether its stand-ins survived. A real mock or Partial already at a stand-in's path is left alone, as is a stand-in that is already current. Mock generation tracks the file at a mock's path as an input, so rewriting one would invalidate the mock for no reason. A stand-in that is out of date, such as a blank one an earlier version wrote, is rewritten.

### Mock search paths

A mock is generated into a directory mirroring its real header's location, and the compiler finds it only if that directory is on the search path. C's `#include` resolution has no recursive search path. So each test's search paths carry one mirrored directory per mock, after the flat mock root, and `mock_search_paths` records which entries those are.

Where the paths come from follows which `#include` list drives the build:

- **Stage 2** collects them from the text-scan list. With test preprocessing off, that list is the build's own, and a mock whose header doesn't exist stops the build. With test preprocessing on, a scanned mock may sit in a branch the preprocessor discards, so one without a header is skipped.
- **Stage 4's first pass** replaces them with the directories of the candidates' mocks. Reconciliation draws only on the candidates, so these cover every mock the build will use, including one only the preprocessor sees, such as one a macro names. The paths must be settled here, not later, because pass 2 already needs them to find the stand-ins.
- **Stage 4's third pass** narrows them to the reconciled list's mocks, dropping directories for candidates the preprocessor discarded.

Every stage that resolves a mock's header does so through `MockLocator`, against the test's search paths minus its `mock_search_paths`, so stages 2, 4, and 5 resolve each mock identically.

## Stop points

A run can stop early by including one of four mutually exclusive Symbols in `PipelineState#options`. Each names a different place to stop, so supplying more than one is rejected.

| Option | Effect | Used by |
|---|---|---|
| `:mocking` | Stops after stage 10 | `gen:mocks` tasks |
| `:test_runner` | Stops after stage 13 | `gen:test_runner` tasks |
| `:sources_only` | Skips stages 15-17, running only enough to fill in each test's sources | callers wanting dependency information, such as the gcov plugin |
| `:build_only` | Skips stage 17, so tests compile and link but never run | `test:build_only` |

A fifth option, `:refresh_dependencies`, is not a stop point, and no stage reads it. `TestInvoker` reads it to decide whether the dependency cache should prune entries for targets this run never touched.

There is no "stop the pipeline" signal. Every stage is still visited, and each carries a condition that checks `PipelineState#options` and skips the stage when there is nothing to do. A `:mocking` run doesn't end the loop after stage 10; stages 11 through 17 are visited and each declines to run. Feature toggles work the same way: with Partials disabled, stages 6-8 skip by the same mechanism.

The three Partials stages and the two mock stages carry a second check. A project can enable Partials or mocking while a particular run has none of that work, such as a `test:pattern` run over files that use neither. The stage then declines to run as if the feature were off, but logs one line at OBNOXIOUS verbosity saying there was nothing to do, so a narrow run isn't left with headings that have nothing under them.

## Parallelism

Most stages hand their per-test or per-item work to `Batchinator`, which runs the given block once per item on a pool of worker threads sized from the project's thread count. That is why so much pipeline code sits in a block passed to `@batchinator.exec`, guarded by `PipelineState#lock.synchronize` wherever it writes into the shared `testables` Hash, an accumulator list, or a `Testable` another thread may read. Ruby's collections aren't safe for concurrent writes without that guard. Each stage holds the lock only for the write itself, never for the real work, such as preprocessing or compiling, that produced it.
