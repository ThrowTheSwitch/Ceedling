# Stages

Each compile and preprocessor run gets its stage search order from `SearchOrderinator`. Generated directories appear in an order only where the run reads generated files through user text. `BuildPlan` records what one build compiles, links and places, and where each path resolved. Stages write it as they plan and read it afterward, so none searches or looks up what it holds. A release plans its sources the same way a test build does.

## Contents

- [The configured order](#the-configured-order) is the user part of every order.
- [Stage search orders](#stage-search-orders) gives the order of each run, stage by stage.
- [Stage 4](#stage-4) covers finding a test's includes before any mock exists.
- [BuildPlan](#buildplan) covers what the build plan holds, who writes it and who reads it.
- [Stage 15](#stage-15) covers compiling from the plan.
- [Tool outputs](#tool-outputs) covers the files each tool run writes.
- [Release planning](#release-planning) covers the release build.
- [The dependency cache](#the-dependency-cache) covers what is saved between builds.
- [Code](#code) lists the files and the interface.

## The configured order

A test's configured order is its user search paths, in the order the compiler searches them. Every stage search order builds on it.

1. The test's `TEST_INCLUDE_PATH()` directories, in the order the test writes them.
2. Its test roots that hold a header, then its support roots, include roots and library roots, each glob in its expansion order.
3. The framework directories, then `:test_toolchain_include`.
4. The directories that `:files` ↳ `:include` headers outside every root add.

A directory appears once, at its first place, by key.

## Stage search orders

`SearchOrderinator` gives each run one order, and the build plan records it. "Overlays" in the table means each search path's overlay just ahead of it, with quote-rule overlays and reach directories placed as [PLACEMENT.md](PLACEMENT.md#overlays) says.

| Stage | Run | Stage search order |
| --- | --- | --- |
| 2 | text scan | none. Resolution uses the configured order |
| 4, first pass | `-M -MG` on the test file | the stand-in root's overlays and reach directories, the configured order, the stand-in root |
| 4, second pass | directives-only | the same as the first pass |
| 5 | planning | none. Resolution uses the configured order |
| 6, 7 | a Partial module's header and source | the configured order |
| 9 | a mocked header | the configured order |
| 11 | the test file's full expansion | overlays, the configured order, the Partials root |
| 15 | the test file, its sources, runner, mocks, Partials and support files | overlays, the configured order, the Partials root |
| 15 | a framework source | the configured order |
| plugin | an untested source, a cppcheck analysis | the configured order, less `TEST_INCLUDE_PATH()` directories |
| release | a release source | the release's configured order |

- **User files only.** Stages 6, 7 and 9 read user files alone. So a mock that joins or leaves a test reruns none of their runs.
- **Generated text.** Stages 8, 10 and 13 run no compiler search. The files they write hold pinned includes.
- **Routes headers.** A routes header sits at the top of its root, which ends the order of each run that reads a Partial directive.
- **Framework sources.** `unity.c`, `cmock.c` and `cexception.c` compile with the configured order and no overlays. A `unity_config.h` under `:paths` ↳ `:include` and a directory under `:test_toolchain_include` reach them as they reach the test file.
- **Kinds from the plan.** Each object's kind comes from the build plan, so an order never depends on how a path is spelled.
- **Records.** `Resolvinator.resolve( include, search_order: )` takes the order of the run the include belongs to. A resolution record's `order` field holds the stage and the order's digest.
- **Digests.** Each run's dependency record holds its order's digest, so a changed order reruns exactly the runs that use it.

## Stage 4

Stage 4 finds the test file's includes with their macros evaluated, before any mock exists. It reads only stand-ins and user files, and it holds nothing aside. Its overlays below the stand-in root recreate symlinks and form reach directories, as [PLACEMENT.md](PLACEMENT.md#stand-ins) says.

1. **First pass.** The preprocessor runs `-M -MG` on the test file itself, with stage 4's order. `-MG` lists each file it can't find. Each missing file that classifies as a mock include, by [CONVENTIONS.md](CONVENTIONS.md#classification), gets a stand-in.
2. **Rounds.** A new stand-in pins its mocked header, whose macros can name another mock. So the first pass runs again after any round that added a stand-in. It stops when a round adds none, which is usually after the first.
3. **Second pass.** The directives-only run writes line markers. Each depth-1 entry gives its directive's header, as [RESOLUTION.md](RESOLUTION.md#include-records) says.

A mock that a macro from another header names is found this way, since the first pass opens that header. Fallback runs as [RESOLUTION.md](RESOLUTION.md#fallback) says.

## BuildPlan

The build plan is the record of what one build compiles, links and places, and where each path resolved. It is the source of truth. Later stages read it and never search or look up again.

| Part, per test | Holds | Written at |
| --- | --- | --- |
| resolution records | the resolution of every include record in each user file the test's runs enter | stages 2 to 5, and 11 |
| mocks | each mock's identity, placement, include texts and folder | stage 5 |
| Partials | each Partial's identity, placement, module header and source, and route lines | stage 5 |
| stand-ins | each stand-in's placement | stage 4 |
| isolation | each isolation copy with its origin | stages 5 and 14 |
| objects | each object's identity, kind, source, placement and stage search order | stage 14 |
| link set | the objects the test's executable links | stage 14 |
| outputs | the runner, the executable, its results, and the files each tool run writes | stages 5 and 14 |

- **Build-wide.** The plan also holds the generated roots and the framework files' placements.
- **Generated files resolve before they are written.** Resolution answers a generated directory from the plan's placements, as [RESOLUTION.md](RESOLUTION.md#the-model) says.
- **Sources.** Each object records its source, so a compile reads its input from the plan. The Partial stages read a module's header and source there.
- **Lifetime.** The plan lives in memory for one run. The dependency cache saves resolution records, and the ledger saves ownership.
- **Writers.** Stages write a test's part of the plan under the plan's lock. No stage writes it after stage 14.
- **Readers.** Every later stage, the link, the dependency tracker and plugins read it. Plugin hooks receive placements from it.

## Stage 15

Stage 15 compiles every planned object with its planned input and order, as one parallel batch. It writes no plan state, so no object waits on another test's compile.

## Tool outputs

The build plan names each file a tool run writes, from the tool's configuration. A stage waits for a file only when the plan says the tool writes it.

- A compiler whose flags write no dependency file has none planned.
- An assembler run plans no dependency file.
- A link plans a map only when its flags ask for one.

## Release planning

A release build plans its sources, objects and link as a test build does. It needs only `:paths` ↳ `:source`.

- **Sources.** The release's sources are the source collection. Each object records its source, so no object is matched back to a source by its path.
- **Order.** A release source compiles with the release's configured order, which holds no generated directory. It is the configured order without its test parts: the include roots, then the library roots, each glob in its expansion order, then `:release_toolchain_include`, then the directories that `:files` ↳ `:include` headers outside every root add. So a header a test's compile reaches through those roots, a release compile reaches too.
- **Test roots.** A release needs no `:paths` ↳ `:test`. A test task in a project with no test roots fails and names that setting.
- **Outputs.** The target and artifacts follow [PLACEMENT.md](PLACEMENT.md#release-placement).

## The dependency cache

The dependency cache saves each target's resolution records with their misses, its fingerprint and its input files. It also holds the ownership ledger. A delta build compares them with this build's plan, as [RESOLUTION.md](RESOLUTION.md#resolution-records) says. An isolation copy's origin stands for the copy in every record.

## Code

- `lib/ceedling/paths/search_orderinator.rb` holds `SearchOrderinator`, a DIY object. `order( stage:, run:, test: )` returns a list of `PathRef`s, and `digest( order )` returns its digest.
- `lib/ceedling/paths/build_plan.rb` holds `BuildPlan`, a value with one part per test and a lock for its writers. The test and release planners fill it.
- Specs: `spec/units/paths/search_orderinator_spec.rb` checks every row of the table. The contract rows report each object's search paths, so the `DELTA` and `GEN` areas check the orders in real builds.
